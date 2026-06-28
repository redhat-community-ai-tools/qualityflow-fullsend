# QualityFlow — FullSend Integration

FullSend integration layer for [QualityFlow](https://github.com/redhat-community-ai-tools/qualityflow). Provides harness definitions, sandbox policies, CI workflows, and credential templates needed to run QualityFlow agents inside FullSend sandboxes.

## Quick start

Add this to your `.fullsend/customized/harness/qualityflow.yaml`:

```yaml
base: https://raw.githubusercontent.com/redhat-community-ai-tools/qualityflow-fullsend/<sha>/harness/qualityflow.yaml#sha256=<hash>
```

Compute the integrity hash:

```bash
./scripts/compute-integrity.sh <commit-sha>
```

See [docs/fullsend-integration.md](docs/fullsend-integration.md) for the full guide.

## Structure

```
qualityflow-fullsend/
├── qualityflow/     Git submodule → qualityflow-opensource (agents, skills, commands, config)
├── harness/         8 harness YAMLs (7 stages + 1 unified entry point)
├── policies/        4 network policies (qf-full, qf-vertex, qf-codegen, qf-unified)
├── env/             Credential templates (variable expansion, no secrets)
├── scripts/         Pre/post/validation scripts for harness stages
├── schemas/         JSON schemas for output validation
├── images/          Container images (Containerfile for sandbox)
├── plugins/         LSP plugin config (gopls for Go analysis)
├── .github/         CI workflow (triggered by /qf or /fs-plan-tests on PRs)
├── .fullsend/       Consumer harness template
└── docs/            Integration documentation
```

## Updating the QualityFlow submodule

When the upstream QualityFlow repo has new changes:

```bash
git submodule update --remote qualityflow
git add qualityflow
git commit -m "chore: bump qualityflow submodule"
```

Consuming teams then update their `base:` commit pin + integrity hash.

## Network policies

| Policy | Used by | Allows |
|--------|---------|--------|
| `qf-full.yaml` | stp-builder, stp-reviewer, stp-refiner | Jira API, GitHub API, Vertex AI |
| `qf-vertex.yaml` | std-builder, std-reviewer, std-refiner | Vertex AI only |
| `qf-codegen.yaml` | test-generator | Vertex AI, GitHub API, Go/Python registries |
| `qf-unified.yaml` | qualityflow (unified pipeline) | All of the above |

## Cloning

This repo uses git submodules. Clone with:

```bash
git clone --recurse-submodules https://github.com/redhat-community-ai-tools/qualityflow-fullsend.git
```

Or if already cloned:

```bash
git submodule update --init --recursive
```
