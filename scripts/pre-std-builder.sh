#!/usr/bin/env bash
# pre-std-builder.sh — Validate inputs before the STD builder agent runs.
#
# STD builder is file-only (reads STP + config, no external API calls).
#
# Required env vars:
#   JIRA_TICKET — Jira issue key
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

echo "::notice::QualityFlow std-builder: ${JIRA_TICKET:-unset}"

errors=0
require_env JIRA_TICKET || errors=$((errors + $?))
require_jira_format || errors=$((errors + $?))
require_config || errors=$((errors + $?))

if [[ "${errors}" -gt 0 ]]; then
  echo "::error::Pre-script failed with ${errors} error(s). Aborting."
  exit 1
fi

echo "Input validation passed: ${JIRA_TICKET}"
