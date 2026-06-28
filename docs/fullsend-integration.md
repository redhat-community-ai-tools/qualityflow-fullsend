# FullSend Integration Guide

QualityFlow integrates with FullSend as a custom agent. Teams add one
harness file to their `.fullsend` repo, and QF becomes available as a
triggerable pipeline on PRs.

## Quick Start

### 1. Add the harness reference

Create `.fullsend/customized/harness/qualityflow.yaml` in your repo:

```yaml
base: https://raw.githubusercontent.com/<org>/qualityflow/<commit-sha>/harness/qualityflow.yaml#sha256=<hash>
```

Replace `<org>`, `<commit-sha>`, and `<hash>` with:

- `<org>` — the GitHub org or user hosting QualityFlow
- `<commit-sha>` — a full 40-character commit SHA to pin to
- `<hash>` — SHA256 hash of the harness file at that commit

Use the helper script to compute the hash:

```bash
./scripts/compute-integrity.sh <commit-sha>
```

### 2. Configure secrets

Add these secrets to your repo (or org):

| Secret | Purpose |
|--------|---------|
| `FULLSEND_GCP_WIF_PROVIDER` | GCP Workload Identity Federation provider |
| `FULLSEND_GCP_PROJECT_ID` | GCP project for Vertex AI inference |
| `JIRA_URL` | Jira instance URL (optional if using GitHub issues) |
| `JIRA_API_TOKEN` | Jira API token (optional) |
| `JIRA_EMAIL` | Jira user email (optional) |

### 3. Trigger QualityFlow

Comment on any PR:

```text
/qf PROJ-12345
```

Or without a ticket ID (auto-detects from PR title/body/branch):

```text
/qf
```

FullSend trigger: `/fs-plan-tests` (or `/fs-plan-tests PROJ-12345`)

## How It Works

When triggered, QualityFlow runs a 7-stage pipeline:

1. **STP Builder** — Collects Jira/GitHub data, analyzes code with LSP,
   generates a Software Test Plan
2. **STP Reviewer** — Reviews the STP against QE quality standards
3. **STP Refiner** — Fixes review findings (if any)
4. **STD Builder** — Generates test design YAML and stub files from the STP
5. **STD Reviewer** — Reviews the STD for traceability and code readiness
6. **STD Refiner** — Fixes review findings (if any)
7. **Test Generator** — Generates working test implementations

Output is pushed directly to the PR branch:

- Test files are co-located in source packages with a `qf_` prefix
- Pipeline artifacts are saved under `outputs/` (intermediate, can be cleaned)
- `qf_*` files are easily identifiable: `find . -name 'qf_*'`

## Harness Inheritance

The `base:` field uses FS's ADR-0045 inheritance mechanism:

- **Scalars** (model, timeout, policy) — your values override QF defaults
- **Arrays** (skills) — concatenated (QF skills + your additions)
- **Maps** (runner\_env) — merged (your keys override QF keys)
- **Structs** (validation\_loop) — replaced entirely if you set them

### Override examples

Add team-specific environment variables:

```yaml
base: https://raw.githubusercontent.com/<org>/qualityflow/<sha>/harness/qualityflow.yaml#sha256=<hash>

runner_env:
  CUSTOM_JIRA_FIELD: "customfield_10042"
```

Increase timeout for large repos:

```yaml
base: https://raw.githubusercontent.com/<org>/qualityflow/<sha>/harness/qualityflow.yaml#sha256=<hash>

timeout_minutes: 180
```

## Individual Stage Harnesses

For granular control, reference individual stage harnesses instead of
the unified pipeline:

| Stage | Harness File |
|-------|-------------|
| STP Builder | `harness/stp-builder.yaml` |
| STP Reviewer | `harness/stp-reviewer.yaml` |
| STP Refiner | `harness/stp-refiner.yaml` |
| STD Builder | `harness/std-builder.yaml` |
| STD Reviewer | `harness/std-reviewer.yaml` |
| STD Refiner | `harness/std-refiner.yaml` |
| Test Generator | `harness/test-generator.yaml` |

## Updating the Pin

When QF releases a new version:

1. Get the new commit SHA from the QF repo
2. Run `./scripts/compute-integrity.sh <new-sha>`
3. Update the `base:` line in your harness file

## Coverage Dedup

QF automatically avoids duplicating existing test coverage. The regression
analyzer maps existing tests to symbols. If a behavior is already covered,
QF marks it as `EXISTING_COVERAGE` and skips test generation for it.

In PR #2444, QF detected 5 existing FS tests on `findingsToReviewComments`
and generated zero for it, while adding 12 tests covering 8 gaps FS missed.

## Fork PRs

QF pushes test files directly to the PR branch. For fork PRs (where QF
lacks write access), tests are preserved in sandbox artifacts but cannot
be auto-pushed. A companion "eval PR" flow for forks is planned.
