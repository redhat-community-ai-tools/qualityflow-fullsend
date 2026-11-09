## QualityFlow QE review

**Verdict:** APPROVED_WITH_FINDINGS · **Confidence:** MEDIUM · 0 critical, 3 major, 3 minor

Reviewed against **#7231**. Coverage signal: **static** — no coverage report was
available, so every statement below is static reachability, not measured
execution. Nothing here says a line "is not covered"; it says no test in this
PR names it.

### Requirement coverage

| Requirement | Source | Status | Test |
|---|---|---|---|
| Re-mint the push token after the agent exits and before the post-script runs | #7231 suggested-fix | 🟡 partial | `TestRemintAgentTokenForPostScript_PostScriptEnvUsesFreshToken` (helper only — no runAgent-level test) |
| Post-script must push with the live token, not the snapshot taken at run start | #7231 observed (01:56:36 `Invalid username or token`) | ✅ covered | `TestRemintAgentTokenForPostScript_PostScriptEnvUsesFreshToken`, `TestRemintAgentTokenForPostScript_RunnerEnvMissingTokenKeys` |
| Failure-comment path must also authenticate with a live token | #7231 observed (`Failed to post error comment`) | 🟡 partial | `TestRemintAgentTokenForPostScript_ErrorIsNonFatal` (runs a post-script, but nothing asserts the notification path) |
| A remint failure must not discard a completed run | #7231 "Why this matters" | ✅ covered | `TestRemintAgentTokenForPostScript_ErrorIsNonFatal` |
| GitLab / unconfigured mint must skip the remint | PR body, changes | ✅ covered | `TestRemintAgentTokenForPostScript_SkipsMintOnGitLabOrEmptyMintURL` |
| Remint must run even when the run ctx is already cancelled at budget exhaustion | #7231 (agent killed at full budget) | ✅ covered | `TestRemintAgentTokenForPostScript_SurvivesCancelledParentCtx` |
| A remint truncated by its own deadline is distinguishable from a mint rejection | derived from `MaxMintDuration` contract | 🟡 partial | `TestRemintAgentTokenForPostScript_DeadlineExceededGetsDistinctWarning` (stubs `statusMintToken`, never exercises `retryableError.Unwrap`) |

### Findings

**QF-1 · MAJOR · test_level** — The fix's central claim — the remint happens
*after* sandbox teardown and *before* `postCmd` runs — is only tested by calling
`remintAgentTokenForPostScript` directly. No test drives `runAgent` through the
post-script defer, so the placement of the new defer, and the new
`stopOpenAIRefreshers` loop that must stop the refresher goroutines before the
remint's `os.Setenv`, are unexercised. A helper that works in isolation is not
evidence it is wired in at the right point; that wiring is the whole bug.
*Remediation:* add a `runAgent`-level test with a harness that has a
`post_script`, following the existing `TestRunAgent_FallsBackToFULLSEND_MINT_URL`
pattern, asserting the mint stub is called twice and the post-script observes the
second token. *(internal/cli/run_test.go)*

**QF-2 · MAJOR · requirement_coverage** — #7231 calls out the failure-comment
path explicitly ("the failure notification uses the same dead token"), and the
suggested fix says the remint "also fixes the failure-comment path". No test
asserts it. Worse, the ordering may not hold: `remintCleanup` is deferred late in
`runAgent`, so under LIFO it restores the process env *before* any
notification defer registered earlier in the function — and `run.go`'s own new
comment references "the completion-notification defer ... elsewhere in this
file". If that defer posts the failure comment, it runs after the reminted token
has been restored away. *Remediation:* determine whether the failure comment is
posted by `post-code.sh` (covered transitively) or by the Go completion-
notification defer; if the latter, move the remint cleanup so it outlives that
defer and add a test asserting the notification path sees the reminted token.
*(internal/cli/run.go)*

**QF-3 · MAJOR · coverage_gap** — `retryableError.Unwrap` is new production code
with no test that executes it. The test that looks like its coverage,
`TestRemintAgentTokenForPostScript_DeadlineExceededGetsDistinctWarning`, stubs
`statusMintToken` to return `ctx.Err()` unwrapped, so the `errors.Is` path
through a `retryableError` wrapping an in-flight `context.DeadlineExceeded` —
precisely the case the new `Unwrap` exists for — never runs. *Remediation:* add a
test in `internal/mintclient/mintclient_test.go` that makes an HTTP attempt hang
past a context deadline and asserts `errors.Is(err, context.DeadlineExceeded)` on
`MintToken`'s return. *(internal/mintclient/mintclient.go)*

**QF-4 · MINOR · scenario_quality** —
`TestMintToken_SurvivesTransientFailuresWithinMaxMintDuration` sets
`retryBaseDelay` to 10ms and then asserts `elapsed < MaxMintDuration` (120s). That
assertion cannot fail, so it does not defend the invariant its own docstring
claims: that `MaxMintDuration` is not shorter than the client's real ~18s backoff
schedule. Lowering `MaxMintDuration` to 5s would keep this test green while
reintroducing the truncated-retry failure the const doc warns about.
*Remediation:* add a direct assertion on the constant (e.g. `MaxMintDuration >=
18*time.Second`, or compute the schedule sum from `retryBaseDelay` and the
attempt counts) rather than relying on wall-clock elapsed.
*(internal/mintclient/mintclient_test.go)*

**QF-5 · MINOR · scenario_quality** — `syncRunnerEnvTokens` iterates
`roleTokenVars[resolveRole(h.Role)]`, but every new test uses `Role: "coder"`. The
`triage` (`TRIAGE_TOKEN`) and `review` (`REVIEW_TOKEN`) role paths are never
exercised, so a role-map regression would not be caught. *Remediation:* make the
sync test table-driven over the roles in `roleTokenVars`.
*(internal/cli/run_test.go)*

**QF-6 · MINOR · scenario_quality** — In `syncRunnerEnvTokens`, the
`os.LookupEnv` not-found branch (key present in `RunnerEnv`, absent from process
env) has no test. `TestRemintAgentTokenForPostScript_RunnerEnvMissingTokenKeys`
covers the mirror case only. *Remediation:* add a case asserting a `RunnerEnv`
entry is left untouched when the corresponding env var is unset.
*(internal/cli/run_test.go)*

### Uncovered changed lines

Not available — no coverage report for this PR. The gaps above are static: no
test in this PR references the `runAgent` post-script defer block, the
`stopOpenAIRefreshers` loop, or `retryableError.Unwrap`.

<sub>Read-only review. To generate the missing tests, comment `/fs-plan-tests`.</sub>
