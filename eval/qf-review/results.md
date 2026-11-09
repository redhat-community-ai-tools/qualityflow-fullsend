# Eval results — qualityflow-reviewer, rounds 1 and 2

Method: three merged fullsend PRs, bundled offline (diff + linked issue only —
no network, no repo checkout, no QF skills). Ground truth in `expected.md` was
written before any agent output was read. Each run also reported defects in the
prompt itself, which is where most of the value came from.

## Round 1 — original prompt

| PR | Expected | Agent | Match |
|---|---|---|---|
| 7215 hyphen-in-role fix | AWF, major on the shell/YAML side | AWF · 0C/1M, major = `setup-agent-env.sh` | yes |
| 7262 drain helper | NEEDS_REVISION, AC4 unbuilt | NEEDS_REVISION · 3C/3M/2m, AC4 headline | yes |
| 7234 token remint | APPROVED-ish, no invented criticals | AWF · 0C/3M/3m | yes, no invented criticals |

7234's three majors were substantive, not noise: the remint helper is unit
tested in isolation while the defer placement that *is* the bug is never driven
through `runAgent`, and `retryableError.Unwrap` never executes in the test that
appears to cover it. Both on a merged, human-reviewed PR.

### Defects found (all fixed)

1. **The error path could never validate.** `status: error` added `reason` to
   required but left the five success fields required. Any PR with no linked
   issue would produce output the harness rejects. Blocking.
2. **Unimplemented was indistinguishable from untested.** AC4 in 7262 is unbuilt
   code, not a missing test; the rubric forced it into `requirement_coverage`
   and then recommended `/fs-plan-tests`, which is the wrong remedy.
3. `APPROVED` was unreachable — one naming nit downgraded it.
4. `partial` was undefined, and it decides CRITICAL vs MAJOR.
5. No confidence ladder; `coverage_signal` was in the schema and the hard rules
   but in no workflow step; `coverage_gap` was unreviewable without coverage.
6. The worked example contradicted itself (header counts vs JSON).

## Round 2 — 7262 re-run against the fixed prompt

Verdict held: NEEDS_REVISION · 1C/4M/1m · confidence LOW · escalate false.
AC4 and AC5 now come back as `unimplemented` under `scope_gap`, and escalation
correctly does not fire for missing code. All five round-1 defects confirmed
fixed; `partial`'s three shapes mapped one-to-one onto three requirements that
were coin flips before.

### New defects found (all fixed)

1. **The example contradicted itself again** — header said 1C/1M, body had two
   criticals, JSON said 2C/0M, `items` had one entry against `total: 2`. Now
   pinned by `check.sh`, which fails if the example ever drifts from the schema
   or from its own header.
2. **Requirement counters could not sum** — no `unimplemented` counter, so two
   requirements vanished from the arithmetic while a hard rule demanded the
   counts agree. Added to schema (required) and prompt.
3. **`unimplemented` collided with not-unit-testable** — AC5 is both, and the
   rules gave opposite severities. Precedence added: unimplemented wins,
   because missing code is actionable even when verifying it is not.
4. **`escalate` was vetoed by a single unimplemented requirement.** Now they
   simply do not count toward the three.
5. **No handling for a deliberately-rejected acceptance criterion** — 7262
   argues, correctly, that AC2's second clause cannot be implemented as
   written. That is a design decision, not a coverage gap: now `scope_gap` /
   MINOR with the PR's rationale quoted.
6. Pin ambiguity: a grep assertion inside a shell test script is still a pin.

## Known gaps

- The four round-1/round-2 result files no longer validate: they predate the
  `unimplemented` counter. Kept as-is; they are the record of the run.
- Everything so far is offline. The skills (`pr-analyzer` coverage gaps,
  `project-resolver`, `test-strategy-resolver`) were simulated by the model
  reading the diff. The plumbing is untested — only the judgment is.
- No round-2 re-run of 7215 or 7234 against the fixed prompt.
