## Issue #7140
**Custom harness dispatch fails when role contains a hyphen**

Labels: type/bug, triaged, priority/high, component/dispatch, bug

### What happens

The custom-harness matrix job in `.github/workflows/reusable-dispatch.yml` builds per-role environment variables by uppercasing `matrix.role` and exporting names like `${ROLE_UPPER}_TARGET_REPO_DIR`. A hyphen in the role is left in place, so bash rejects the `export`:

```
/home/runner/work/_temp/dec794e5-1dcf-4f9c-a8f6-c08be415b4bb.sh: line 4: export: `CI-CHECK_TARGET_REPO_DIR=target-repo': not a valid identifier
```

The failing step is **Setup agent environment**:

```bash
ROLE_UPPER=$(echo "${MATRIX_ROLE}" | tr '[:lower:]' '[:upper:]')
export AGENT_PREFIX="${ROLE_UPPER}_"
export "${ROLE_UPPER}_TARGET_REPO_DIR=target-repo"
export "${ROLE_UPPER}_ANTHROPIC_VERTEX_PROJECT_ID=${GCP_PROJECT}"
export "${ROLE_UPPER}_CLOUD_ML_REGION=${GCP_REGION}"
```

Built-in stages do not hit this: they hardcode prefixes without hyphens (`TRIAGE_`, `CODE_`, `REVIEW_`, `FIX_`, `RETRO_`, `PRIORITIZE_`). Only the custom-harness job derives the prefix from `matrix.role` at runtime.

### What should happen

A harness whose `role` is a documented-valid name that includes a hyphen (for example `ci-check`, `deploy-prod`, `my-role`) should get through **Setup agent environment** and run.

Role-prefixed identifiers (env vars, GitHub Actions variables/secrets, and similar) must map the role with `role.upper().replace("-", "_")`. For `ci-check` that is `CI_CHECK_TARGET_REPO_DIR`, not `CI-CHECK_TARGET_REPO_DIR`. Every downstream consumer of those variables has to use the same mapping to look them up; uppercasing alone is not enough.

Hyphens are allowed by `mintcore.RolePattern` (`^[a-z][a-z0-9_-]*$`, no `--`) and by the standalone mint / harness docs.

### How to reproduce

1. Register a custom role whose name contains a hyphen (e.g. `ci-check`) on a standalone mint, and point a repo at that mint.
2. Add a harness with `role: ci-check` so it is selected by the custom-harness matrix in `reusable-dispatch.yml`.
3. Trigger that agent.
4. The job fails at **Setup agent environment** with `export: 'CI-CHECK_TARGET_REPO_DIR=target-repo': not a valid identifier`.

### Context

`setup-agent-env.sh` copies env vars whose names start with `AGENT_PREFIX` (and looks up role-prefixed repo variables such as `<ROLE>_FULLSEND_MODEL`). That prefix is the uppercased role plus `_`. GitHub Actions env/secret/variable names cannot contain hyphens, so a hyphenated role also cannot be expressed as a repo variable like `CI-CHECK_FULLSEND_MODEL`.

Call sites that already map hyphens to underscores when building identifiers include Cloudflare PEM secret names (`internal/dispatch/cf/provisioner.go`). Call sites that uppercase the role without replacing hyphens include this dispatch step, GitHub App secret names (`FULLSEND_<ROLE>_APP_PRIVATE_KEY`), and `FULLSEND_FOREIGN_<ROLE>_REPOS`.

