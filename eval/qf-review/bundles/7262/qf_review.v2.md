## QualityFlow QE review

**Verdict:** NEEDS_REVISION · **Confidence:** LOW · 1 critical, 4 major, 1 minor

Reviewed against **#7257**. Coverage was not measured — every statement below is
static reachability, not execution. No repo checkout was available either, so
conventions were inferred from the test files in the diff.

### Requirement coverage

| Requirement | Source | Status | Test |
|---|---|---|---|
| `drain_runner_vm` exists, graceful, bounded (10-min default), drain-then-proceed | issue:AC1 | ⚠️ partial | `drain_runner_vm: idle on first poll reports OK`, `…: cap overrun warns and proceeds`, `…: non-numeric DRAIN_TIMEOUT_SEC falls back to 600`, `…: signal failure warns and still polls` |
| Deleting a fleet VM succeeds without `GL_TOKEN` and does not touch the shared runner | issue:AC2 | ⚠️ partial | `delete-gcp-vm.sh: neither RUNNER_TOKEN nor GL_TOKEN fails closed`, `delete-openshift-vm.sh: …fails closed` |
| `delete-*-vm.sh` drains before deletion; `--no-drain` skips it | issue:AC3 | ⚠️ partial | `delete-gcp-vm.sh: exports closure variables before drain_runner_vm`, `delete-openshift-vm.sh: exports closure variables before drain_runner_vm` |
| `create-*-vm.sh --recreate` drains → deletes → recreates; refuse-on-existing unchanged without the flag | issue:AC4 | ⛔ unimplemented | — |
| Recreating a fleet VM keeps the shared runner ID stable and does not cut a job inside the drain cap | issue:AC5 | ⛔ unimplemented | — |
| Usage comments in `create-*`/`delete-*` describe capabilities, flags, modes, credentials | issue:AC6 | ⚠️ partial | — (header content changed in `delete-*` only; no `--help` test) |

### Findings

**QF-1 · CRITICAL · scope_gap** — AC4 (`--recreate` on the create scripts) has no
implementation in this PR. Neither `create-gcp-vm.sh` nor `create-openshift-vm.sh`
appears in the diff at all, and the PR body says `Closes #7257`, so the issue will
auto-close with the flag that the issue titles "drained recreation as the lifecycle
path" never built. The code is absent — this is not a testing gap.
*Remediation:* implement `--recreate` (drain → delete → create) in both create
scripts here, or drop the `Closes #7257` keyword so the issue stays open for a
follow-up PR.

**QF-2 · MAJOR · scope_gap** — AC5 (recreating a fleet VM leaves the shared runner
ID stable and does not cut a job finishing inside the drain cap) has no
implementation and no verification path. It depends on AC4, and even once
implemented it cannot be unit-tested: it needs both live fleets (gitlab.com
`56125242`, gitlab.cee `68746`) and a real in-flight job.
*Remediation:* after AC4 lands, verify manually on `runner-01` of each fleet —
start a job, run `create-*-vm.sh --recreate`, confirm the job completes and the
runner ID is unchanged — and record the result on the issue. No unit test can
close this one.

**QF-3 · MAJOR · scenario_quality** — Nothing asserts *how* the drain signals the
runner. The issue's §1 caveats make the signal the crux ("use the graceful signal
(SIGQUIT) rather than a bare `systemctl stop` that trips the 45s abort; account
for `Restart=always`"), and `lib.sh` does exactly that — `systemctl kill -s QUIT`
plus `systemctl mask --runtime`. But no test pins it: `drain_capture_mock` captures
the remote command string and only greps it for `sed -i`, `test -f`, and
`podman ps`. A refactor back to `systemctl stop`, or a dropped `mask --runtime`
letting `Restart=always` revive the runner mid-drain, passes all 13 drain tests.
*Remediation:* extend the existing capture-mock assertion in `lib_test.sh` to also
`grep -Fq -- "-s QUIT"` and `grep -Fq "mask --runtime"` on `${DRAIN_CAPTURE_FILE}`.
Three lines, no new fixture.

**QF-4 · MAJOR · requirement_coverage** — AC2's success path is untested. Both new
delete-script tests assert the *refusal* (neither `RUNNER_TOKEN` nor `GL_TOKEN` →
fail closed). Nothing asserts the thing the AC actually asks for: that
`RUNNER_TOKEN=glrt-xxx` + `GCP_PROJECT` (no `GL_TOKEN`, no `GITLAB_URL`) gets past
credential validation, and that fleet mode skips deregistration rather than
touching the shared runner. The guard is covered; the path operators will use is
not. Separately, note that the PR deliberately implements only half of AC2: the
"no `proj/vm` match" branch still requires `GL_TOKEN`, because the lookup that
proves there is no match needs the token. That looks like the right call (the code
and README both argue it), but it is a documented divergence from the AC as
written and should be reflected on the issue.
*Remediation:* add an `assert_succeeds_with` in `lib_test.sh` running
`with_clean_env RUNNER_TOKEN=glrt-test GCP_PROJECT=my-gcp-project bash "${DELETE_GCP}" fullsend-gitlab-runner-01`
asserting on `skipping GitLab deregistration (fleet mode)`, and the
`NAMESPACE`/`DELETE_OCP` equivalent. Mock or short-circuit the actual
`gcloud`/`virtctl` call the way the create-script tests do.

**QF-5 · MAJOR · requirement_coverage** — AC3 is covered only indirectly. The two
static regressions grep the delete scripts for the `export vm_name …` lines, which
proves the closure variables are exported but not that `drain_runner_vm` runs
*before* the deletion, and `--no-drain` has no assertion of any kind — not a flag-
parse test, not a "skipping drain (--no-drain)" output check. `--no-drain` is the
escape hatch operators reach for when drain misbehaves; it is the one new flag in
this PR and it is entirely unexercised. Static content pins are an established
convention in this file ("static regressions" predates the PR), so they are
legitimate evidence — they just do not reach this behavior.
*Remediation:* add a test asserting `bash "${DELETE_GCP}" --no-drain <vm>` emits
`skipping drain (--no-drain)` and never reaches `draining runner (cap`, plus the
inverse for the default path. The `--no-drain`/`vm_names` split loop is pure
argument parsing and is testable without any cloud call.

**QF-6 · MINOR · requirement_coverage** — AC6 is met for `delete-*` (the header
blocks are thorough) but the mechanism that renders them changed from
`head -26 | tail -24` to an `awk` extraction, and no test covers it. `lib_test.sh`
already asserts `create-openshift-vm.sh --help` renders (`"Join an existing runner
pool"`); the equivalent was not added for either delete script, so a header edit
that breaks the awk boundary would ship silently. The `create-*` half of AC6 is
untouched, which follows from QF-1 — there is no `--recreate` to document yet.
*Remediation:* mirror the existing `--help` assertion for `DELETE_GCP` and
`DELETE_OCP`, e.g. `assert_succeeds_with "…" "Fleet (RUNNER_TOKEN is set" with_clean_env bash "${DELETE_GCP}" --help`.

### Noted in passing

- `delete-gcp-vm.sh` sets `trap 'rm -f "${GCP_KNOWN_HOSTS}"' EXIT` only on the
  non-IAP branch; a later `trap … EXIT` elsewhere in the script would silently
  replace it. Not a test finding — flagging for the code reviewer.

<sub>Read-only review — no tests written, no merge blocked. To generate the
missing tests, comment `/fs-plan-tests`.</sub>
