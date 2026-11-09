# Ground truth — written before reading any agent output

My own read of each PR: what a competent QE reviewer should say. The point of
the eval is whether the agent finds the same things, misses them, or invents
findings that aren't there.

## PR 7215 — fix(#7140): map hyphens to underscores in role identifiers

Issue: a role with a hyphen (`ci-check`) makes the dispatch workflow export
`CI-CHECK_TARGET_REPO_DIR`, which bash rejects. Reported with a stack trace
from the "Setup agent environment" step.

- 23 files, 8 of them `_test.go`, all paired with their source change.
- The Go side (`mintcore.RoleIdentifier` and its 6 call sites) is well covered.
- **The reported failure is not in Go.** It is in `reusable-dispatch.yml` (+4/-1)
  and `setup-agent-env.sh` (+3/-1). Whether the fix actually resolves the
  reported bug is covered only if `workflow_call_alignment_test.go` (+14)
  asserts on the generated export name.

**Expected verdict:** APPROVED_WITH_FINDINGS.
**Expected key finding (MAJOR):** the reproduction case from the issue —
dispatching a `ci-check` role — has no direct test; shell/YAML changes are
verified indirectly at best.
**False-positive risk:** claiming the PR is untested because the workflow file
has no adjacent test file.

## PR 7234 — fix(#7231): remint GitHub App token before post-script

Issue: the App token (60 min) expires exactly when the code agent's budget
(60 min) runs out, so post-script push always fails on a full-budget run.

- 4 files: `run.go` (+124) / `run_test.go` (+298), `mintclient.go` (+32) /
  `mintclient_test.go` (+77). Every production change has a paired test.
- Three stated behaviors: remint after teardown, overlay the new token so the
  last-wins merge cannot restore the stale one, treat remint failure as
  non-fatal. All three are unit-testable and the test volume suggests they are
  tested.

**Expected verdict:** APPROVED, or APPROVED_WITH_FINDINGS with a MINOR.
**Expected key finding, if any (MINOR/MAJOR):** the issue's actual acceptance
condition — a full-budget run pushes successfully — is an integration
property no unit test here proves.
**False-positive risk:** inventing critical gaps in a PR that is genuinely
well tested. This is the case that tests whether the agent can say "fine".

## PR 7262 — feat(#7257): add drain_runner_vm helper for GitLab runner VMs

Issue has **six explicit acceptance criteria**. PR body says "Closes #7257".

- 5 files: `lib.sh` (+226) with `lib_test.sh` (+331, new), both delete scripts,
  README.
- **`create-gcp-vm.sh` and `create-openshift-vm.sh` are not touched.** So
  AC4 (`--recreate` drains, deletes, recreates) is neither implemented nor
  tested, while the PR claims to close the issue.
- AC1 (drain helper, unit-tested, bounded, drain-then-proceed) looks covered by
  the new `lib_test.sh`.
- AC2/AC3 (fleet-aware delete without GL_TOKEN, drain before delete,
  `--no-drain`) are implemented in the delete scripts; whether `lib_test.sh`
  reaches them needs checking in the diff.
- AC5 (recreating a fleet VM keeps the runner ID stable, does not cut a job) is
  an infrastructure property no shell unit test can prove.

**Expected verdict:** NEEDS_REVISION.
**Expected key finding (CRITICAL):** AC4 has no implementation and no test in a
PR that claims to close the issue. This is the finding that makes the agent
worth running — a reviewer who only checks "did tests change?" passes this PR.
**False-positive risk:** flagging AC5 as a missing test when it is not
unit-testable, without saying so.

## What counts as a pass for this eval

1. Does it flag 7262's AC4 gap? (the high-value finding)
2. Does it leave 7234 mostly alone? (no invented criticals on good work)
3. Does it notice 7215's Go-tests-but-shell-bug asymmetry? (the subtle one)
4. Does every "covered" claim name a real test function?
