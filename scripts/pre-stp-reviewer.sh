#!/usr/bin/env bash
# pre-stp-reviewer.sh — Validate inputs before the STP reviewer agent runs.
#
# Required env vars:
#   JIRA_TICKET      — Jira issue key
#   JIRA_BASE_URL    — Jira instance URL
#   JIRA_API_TOKEN   — Jira API token
#   JIRA_USER_EMAIL  — Jira user email
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

echo "::notice::QualityFlow stp-reviewer: ${JIRA_TICKET:-unset}"

errors=0
require_env JIRA_TICKET JIRA_BASE_URL JIRA_API_TOKEN JIRA_USER_EMAIL || errors=$((errors + $?))
require_jira_format || errors=$((errors + $?))
require_config || errors=$((errors + $?))

if [[ "${errors}" -gt 0 ]]; then
  echo "::error::Pre-script failed with ${errors} error(s). Aborting."
  exit 1
fi

echo "Input validation passed: ${JIRA_TICKET}"
