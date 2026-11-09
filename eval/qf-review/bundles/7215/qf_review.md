## QualityFlow QE review

**Verdict:** APPROVED_WITH_FINDINGS · **Confidence:** MEDIUM · 0 critical, 1 major, 3 minor

Coverage signal is **static** (reachability from the diff only — no coverage report was
available). Nothing below is measured execution.

### Requirement coverage

| Requirement | Source | Status | Test |
|---|---|---|---|
| A harness whose `role` contains a hyphen (`ci-check`) gets through **Setup agent environment** | #7140 (What should happen / repro) | ✅ covered | `TestHarnessRunMapsHyphensInRoleIdentifiers` |
| Role-prefixed identifiers map the role with `role.upper().replace("-","_")`, in one shared helper | #7140 (What should happen) | ✅ covered | `TestRoleIdentifier` |
| Every downstream consumer of role-prefixed identifiers uses the same mapping | #7140 (What should happen / Context) | ⚠️ partial | `TestRoleAppPrivateKeySecret`, `TestSecretAndVariableNames_HyphenatedRole`, `TestForeignVariableName`, `TestForeignAllowCmd_HyphenatedRole`, `TestPemSecretName`, `TestRunGitHubStatus_ForeignVariableOmitsParsedRole` |

### Findings

**QF-1 · MAJOR · requirement_coverage** — The last consumer named in the issue's Context
section, `setup-agent-env.sh`, is the only one with no test. It looks up role-prefixed repo
variables (`<ROLE>_FULLSEND_MODEL`) off `AGENT_PREFIX`, and this PR changes only its header
comment (+3/-1, no code). Nothing asserts that a `CI_CHECK_FULLSEND_MODEL` repo variable is
picked up for role `ci-check` — the fix is inherited from the workflow via `AGENT_PREFIX` and
is untested at that boundary.
*Remediation:* add a test that runs `setup-agent-env.sh` with `AGENT_PREFIX=CI_CHECK_` and a
`FULLSEND_REPO_VARS` map containing `CI_CHECK_FULLSEND_MODEL`, asserting the role-prefixed
override wins over the plain `FULLSEND_MODEL`.

**QF-2 · MINOR · coverage_gap** — The embedded mint copy
`internal/dispatch/gcf/mintsrc/mintcore/patterns.go.embed` gains `RoleIdentifier` (+11) and
`foreign.go.embed` starts calling it, but no test in this PR touches the `.embed` copies;
`TestRoleIdentifier` was added only for `internal/mintcore`. The added embed lines are not
executed by anything in the diff.
*Remediation:* confirm the existing embed/source drift check covers
`patterns.go.embed`; if it does not enumerate this file, extend it so the GCF copy cannot
diverge from `internal/mintcore/patterns.go`.

**QF-3 · MINOR · rule_compliance** — `parseForeignVariableName` has at least two call sites;
only `runGitHubStatus` was corrected to stop printing the lossily reconstructed role
(`CI_CHECK` → `ci_check`). `internal/cli/foreign.go` is touched in this PR for help text only,
so any role rendering in its list/deny output would still show a role the user never typed.
*Remediation:* grep every `parseForeignVariableName` caller and apply the same
name-only rendering; add the `NotContains "(ci-check)"` assertion to the foreign-list test
the way `TestRunGitHubStatus_ForeignVariableOmitsParsedRole` does.

**QF-4 · MINOR · scenario_quality** — The collision this mapping introduces (`ci-check` and
`ci_check` share `CI_CHECK`, so they share `FULLSEND_CI_CHECK_APP_PRIVATE_KEY` and the FOREIGN
allow-list) is documented in `standalone-mint.md` and pinned at the helper level
(`{"my-role","MY_ROLE"}`, `{"my_role","MY_ROLE"}`), but nothing detects or rejects two
colliding roles at registration — one role silently overwrites the other's credential. Out of
scope for #7140; raising it because the PR is what creates the collision.
*Remediation:* decide whether `ValidateRoleName`/role registration should reject a role whose
`RoleIdentifier` already exists, then test it. Needs a product call first.

### Uncovered changed lines

Not determined — no coverage signal was available for this review. Static reachability only.

<sub>Read-only review. To generate the missing tests, comment `/fs-plan-tests`.</sub>
