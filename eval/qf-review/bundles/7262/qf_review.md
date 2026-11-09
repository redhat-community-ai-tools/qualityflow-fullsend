## QualityFlow QE review

**Verdict:** NEEDS_REVISION · **Confidence:** MEDIUM · 3 critical, 3 major, 2 minor

Coverage signal: **static reachability only** — no coverage report was available for this
PR, so nothing below is measured execution. Where a requirement is called covered, the
pinning assertion in `lib_test.sh` is named.

### Requirement coverage

| Requirement | Source | Status | Test |
|---|---|---|---|
| AC1 — `drain_runner_vm` in `lib.sh`, unit-tested, graceful, bounded (10-min default), drain-then-proceed | #7257:AC1 | ✅ covered | `lib_test.sh`: "idle on first poll reports OK", "cap overrun warns and proceeds", "non-numeric DRAIN_TIMEOUT_SEC falls back to 600", "persistent poll failure retries then gives up at cap" |
| AC2 — fleet VM deletes without `GL_TOKEN`, shared runner untouched | #7257:AC2 | ⚠️ partial | `lib_test.sh`: "neither RUNNER_TOKEN nor GL_TOKEN fails closed" (×2) — negative guard only |
| AC3 — `delete-*-vm.sh` drains before delete; `--no-drain` skips | #7257:AC3 | ❌ uncovered | — (only a `grep` for the `export …` line) |
| AC4 — `create-*-vm.sh --recreate` drains → deletes → recreates | #7257:AC4 | ❌ uncovered | — (not implemented in this PR) |
| AC5 — recreate keeps shared runner ID stable, does not cut an in-cap job | #7257:AC5 | ❌ uncovered | — |
| AC6 — usage comments in `create-*`/`delete-*` describe flags, modes, credentials | #7257:AC6 | ⚠️ partial | `delete-*` headers rewritten, no `--help` test; `create-*` headers untouched |

### Findings

**QF-1 · CRITICAL · requirement_coverage** — AC4 is neither implemented nor tested. The PR
body says `Closes #7257`, but no `create-gcp-vm.sh` / `create-openshift-vm.sh` change is in
the diff, so `--recreate` (drain → delete → create in one credential-consistent command) —
the headline deliverable of the issue — does not exist.
*Remediation:* either add `--recreate` to both create scripts with `lib_test.sh` coverage
(flag parsed, refuse-on-existing preserved without the flag), or downgrade the PR link to
`Refs #7257` and keep the issue open.

**QF-2 · CRITICAL · requirement_coverage** — AC3's `--no-drain` escape hatch has no test at
all. The new argument loop in both delete scripts partitions `$@` into `--no-drain` vs
`vm_names`, and nothing asserts the flag is stripped from the VM list or that the
`skipping drain (--no-drain)` branch is taken. A regression that treats `--no-drain` as a
VM name would pass CI.
*Remediation:* in `lib_test.sh`, add `assert_fails_with "delete-gcp-vm.sh: --no-drain is not
a VM name" "specify at least one VM name" with_clean_env GCP_PROJECT=p RUNNER_TOKEN=glrt-x
bash "${DELETE_GCP}" --no-drain` (and the OpenShift twin) — this runs offline, with no
gcloud/virtctl.

**QF-3 · CRITICAL · requirement_coverage** — AC5 ("recreating a fleet VM leaves the shared
runner ID stable and does not cut a job that finishes within the drain cap") has no
verification of any kind. It is the one acceptance criterion that states the actual user
outcome, and it is neither unit-testable from `lib_test.sh` nor covered by an e2e or a
documented manual runbook step in this PR.
*Remediation:* add a manual verification note to `hack/gitlab-runner-vm/README.md` (drain a
VM with a live job, confirm runner ID `56125242`/`68746` unchanged and the job completes),
or file a follow-up for an e2e. Not actionable by a code agent offline.

**QF-4 · MAJOR · requirement_coverage** — AC2 is only tested in the negative. Both new tests
assert that *neither* token fails closed; nothing asserts the positive path the AC actually
states: with `RUNNER_TOKEN` set and no `GL_TOKEN`, validation passes and deregistration is
skipped. The `lookup_runners=false` branch and the `skipping GitLab deregistration (fleet
mode)` output are unexercised.
*Remediation:* add a test running `with_clean_env GCP_PROJECT=p RUNNER_TOKEN=glrt-x bash
"${DELETE_GCP}" fullsend-gitlab-runner-01` and assert the output does **not** contain
`GL_TOKEN is required` (it will fail later on missing `gcloud`, which is fine — assert on
the absence of the credential error).

**QF-5 · MAJOR · scenario_quality** — the two caveats the issue explicitly said the
implementation must not get wrong are the two the tests do not pin: that the drain uses
**SIGQUIT** rather than a bare `systemctl stop` (which trips Fedora's 45s
`TimeoutStopUSec` abort), and that the unit is **runtime-masked** so `Restart=always` cannot
restart the runner mid-drain. `drain_capture_mock` already captures the remote command
string, so both are one `grep -Fq` away.
*Remediation:* extend the `drain_capture_mock` block in `lib_test.sh` to assert the captured
command contains `-s QUIT`, `systemctl mask --runtime gitlab-runner.service`, and no bare
`systemctl stop gitlab-runner`.

**QF-6 · MAJOR · test_level** — `--help` in both delete scripts was rewritten from
`head -26 | tail -24` to an `awk` header scan, and neither rewritten path has a test —
while `lib_test.sh` contains exactly this smoke test for `create-gcp-vm.sh --help` and
`create-openshift-vm.sh --help` a few lines above. An `awk` guard that silently prints
nothing (e.g. after a header edit that changes the comment prefix) would not fail CI.
*Remediation:* add `assert_succeeds_with "delete-gcp-vm.sh --help lists modes" "--no-drain"
with_clean_env bash "${DELETE_GCP}" --help` and the OpenShift twin, mirroring the existing
create-script assertions.

**QF-7 · MINOR · scenario_quality** — no drain test covers the ordinary busy→idle
transition. Every mock is always-idle, always-busy, always-failing, or service-active with
an empty container list; none returns a `runner-*` container on one poll and idle on the
next, which is the normal successful drain.
*Remediation:* add a counter mock that prints `runner-abc123` on poll 1 and
`__SVC__inactive` on poll 2, asserting `OK: runner idle` appears without `drain cap`.

**QF-8 · MINOR · rule_compliance** — four of the new checks are source-text `grep`s against
`lib.sh` / the delete scripts (`export vm_name …`, `1i shutdown_timeout`,
`sudo chown "$cfg_owner"`, `systemctl is-active`). They assert that a string exists, not that
the behavior happens, so they pass on dead or unreachable code and break on harmless
refactors. Two of them duplicate assertions the `drain_capture_mock` test already makes
behaviorally.
*Remediation:* keep the greps that have no behavioral equivalent, and drop the two that
`drain_capture_mock` already covers behaviorally, to avoid pinning implementation text twice.

### Uncovered changed lines

Static reachability, **not** measured coverage — no coverage report was available:

- `hack/gitlab-runner-vm/delete-gcp-vm.sh` — `gcp_drain_ssh()` body, the `--no-drain`
  branch, the `GCP_USE_IAP` validation, and the `GCP_KNOWN_HOSTS` trap: no test invokes them.
- `hack/gitlab-runner-vm/delete-openshift-vm.sh` — `ocp_drain_ssh()` body, the `--no-drain`
  branch, and the `VM_USER`/`RUNNER_USER` validation: no test invokes them.
- `hack/gitlab-runner-vm/lib.sh` — the remote-script heredocs are asserted as *strings*
  via `drain_capture_mock`; no test executes them, so in-guest behavior is unverified by
  design (acceptable for a remote script, noted for completeness).

<sub>Read-only review. To generate the missing tests, comment `/fs-plan-tests`.</sub>
