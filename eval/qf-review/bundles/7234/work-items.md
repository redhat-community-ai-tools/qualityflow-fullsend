## Issue #7231
**Code agent's 60-minute budget equals the GitHub App token lifetime; post-script cannot push on full-budget runs**

Labels: type/bug, triaged, priority/high, component/mint, component/ci, bug, needs-human

## What's broken

The code agent's per-iteration budget is now 60 minutes (fullsend-ai/agents@c723fe33, for fullsend-ai/agents#1259). A GitHub App installation token also lives for 60 minutes. The post-script runs *after* the agent's budget is spent and after sandbox teardown, so on any run that uses its full budget the post-script is guaranteed to authenticate with an expired token.

The failure is not a lost race — with these two durations equal, there is no ordering in which a full-budget run can push.

## Observed

Run 34548284669, job "dispatch / Code" ([step 10](https://github.com/fullsend-ai/fullsend/actions/runs/34548284669/job/103105584668)), on #7218:

| Time (UTC) | Event |
|---|---|
| 00:52:11 | Coder token minted (`Token source: github-app`) |
| 00:53:43 | Runner prints `Timeout: 60 minutes` |
| 00:54:54 | Agent starts |
| ~01:52:11 | Installation token reaches its 1-hour expiry |
| 01:54:58 | Agent killed at full budget, `Agent exit code: -1` |
| 01:55:44 | `Sandbox deleted (46.0s)`; post-script starts (3m33s past expiry) |
| 01:55:45 | First API call returns `"message": "Bad credentials", "status": "401"` |
| 01:56:36 | `remote: Invalid username or token` → `fatal: Authentication failed` (4m25s past expiry) |
| 01:56:36 | `Posting failure comment to issue #7218...` → `Failed to post error comment` |

The work itself was complete: the agent finished its edits and `Pre-commit passed — all hooks clean` immediately before the push. All of it was discarded at the final step.

The failure notification uses the same dead token, so the issue received no comment either. The run failed loudly in Actions, but silently from the perspective of anyone watching #7218.

## Why this matters

This converts the failure mode #1259 set out to fix rather than removing it. Before the raise, the agent was killed before it could commit. After it, the agent finishes and cannot push. #7218 has now failed both ways, and will keep failing this way on every attempt that uses the full budget.

## Suggested fix

Re-mint the push token after the agent exits and before the post-script runs. That is the only option that leaves a full 60-minute budget usable, and it also fixes the failure-comment path, which needs a live token precisely when things have gone wrong.

Interim mitigation if that is not quick: drop the code budget below the token lifetime with margin for teardown (teardown alone was 46s here), which means roughly 50 minutes rather than 60.

Worth noting that #2138 (post-script-only retry) does not help on its own — retrying with the same expired token fails identically. #5312 (least-privilege mint per run phase) would solve this as a side effect, since a post-script-phase token would be minted at post-script time.

## Related

- fullsend-ai/agents#1259 — the budget raise this regressed from
- fullsend-ai/agents#1256 — the earlier silent-success misreport on the same issue
- #2138, #5312 — adjacent, neither sufficient alone
- #7223 — if a per-agent timeout becomes settable from config, it needs a ceiling tied to the token lifetime, or a repo can configure this failure directly

A separate, smaller defect in `post-code.sh` (it interpolated the 401 response body into a branch-name warning instead of failing fast) is being handled in the agents repo and is not part of this issue.


