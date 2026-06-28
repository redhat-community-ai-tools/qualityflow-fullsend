#!/usr/bin/env bash
# common.sh — Shared functions for QualityFlow pre/post scripts.
#
# Source this file at the top of any QF script:
#   SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
#   source "${SCRIPT_DIR}/lib/common.sh"

# require_env — Fail if any listed env var is empty or unset.
# Usage: require_env JIRA_TICKET JIRA_BASE_URL
require_env() {
  local errors=0
  for var in "$@"; do
    if [[ -z "${!var:-}" ]]; then
      echo "::error::${var} is required but not set"
      errors=$((errors + 1))
    fi
  done
  if [[ "${errors}" -gt 0 ]]; then
    return 1
  fi
}

# require_jira_format — Validate JIRA_TICKET matches PROJECT-NUMBER.
require_jira_format() {
  local ticket="${1:-${JIRA_TICKET:-}}"
  if [[ ! "${ticket}" =~ ^[A-Z][A-Z0-9]+-[0-9]+$ ]]; then
    echo "::error::JIRA_TICKET must match PROJECT-NUMBER format, got: '${ticket}'"
    return 1
  fi
}

# require_config — Validate the QF config directory exists.
require_config() {
  local config_dir="${QF_CONFIG_DIR:-/tmp/workspace/agent-input}"
  if [[ ! -d "${config_dir}" ]]; then
    echo "::warning::Config directory not found at ${config_dir} (will be available inside sandbox via agent_input)"
    return 0
  fi
  if [[ ! -f "${config_dir}/routing.yaml" ]]; then
    echo "::warning::routing.yaml not found in ${config_dir} (will be available inside sandbox via agent_input)"
    return 0
  fi
  echo "OK: config directory at ${config_dir}"
}

# scan_output_secrets — Run gitleaks on the output directory.
# Uses gitleaks in --no-git mode (output is generated files, not a repo).
# Non-fatal if gitleaks is not installed (warning only).
scan_output_secrets() {
  local output_dir="$1"
  if [[ ! -d "${output_dir}" ]]; then
    echo "::warning::Output directory not found for secret scan: ${output_dir}"
    return 0
  fi

  if command -v gitleaks >/dev/null 2>&1; then
    echo "Running gitleaks scan on ${output_dir}..."
    if gitleaks detect --source="${output_dir}" --no-git 2>&1; then
      echo "OK: no secrets detected"
    else
      echo "::error::gitleaks detected potential secrets in output"
      return 1
    fi
  else
    echo "::warning::gitleaks not installed — skipping secret scan"
  fi
}

# find_last_output_dir — Locate the most recent iteration's output directory.
# FullSend creates iteration-N/output/ directories; we want the last one.
find_last_output_dir() {
  local output_dir=""
  for dir in iteration-*/output; do
    if [[ -d "${dir}" ]]; then
      output_dir="${dir}"
    fi
  done
  if [[ -z "${output_dir}" ]]; then
    local fallback="${FULLSEND_OUTPUT_DIR:-$(pwd)/output}"
    if [[ -d "${fallback}" ]]; then
      output_dir="${fallback}"
    fi
  fi
  echo "${output_dir}"
}
