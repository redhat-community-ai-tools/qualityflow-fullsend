#!/usr/bin/env bash
# pre-test-generator.sh — Validate inputs before the unified test generator runs.
#
# Required env vars:
#   JIRA_TICKET     — Jira issue key (or GH-NNN for GitHub issues)
#   GH_TOKEN        — GitHub token for repo file fetches
#
# Optional env vars:
#   SOURCE_REPO_DIR — Path to source code repository for co-located test placement
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

echo "::notice::QualityFlow test-generator: ${JIRA_TICKET:-unset}"

errors=0
require_env JIRA_TICKET GH_TOKEN || errors=$((errors + $?))
require_jira_format || errors=$((errors + $?))
require_config || errors=$((errors + $?))

if [[ "${errors}" -gt 0 ]]; then
  echo "::error::Pre-script failed with ${errors} error(s). Aborting."
  exit 1
fi

# --- Verify source repo is usable for co-located test placement ---
if [[ -n "${SOURCE_REPO_DIR:-}" ]]; then
  if [[ -d "${SOURCE_REPO_DIR}" ]]; then
    if [[ -f "${SOURCE_REPO_DIR}/go.mod" ]]; then
      echo "OK: Go module found at ${SOURCE_REPO_DIR}/go.mod"
    elif [[ -f "${SOURCE_REPO_DIR}/pyproject.toml" ]] || [[ -f "${SOURCE_REPO_DIR}/setup.py" ]]; then
      echo "OK: Python project found at ${SOURCE_REPO_DIR}"
    else
      echo "::warning::SOURCE_REPO_DIR set but no go.mod or pyproject.toml found — tests will use outputs/ fallback"
    fi
  else
    echo "::warning::SOURCE_REPO_DIR set but directory does not exist: ${SOURCE_REPO_DIR}"
  fi
fi

echo "Input validation passed: ${JIRA_TICKET}"
