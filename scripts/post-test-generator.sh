#!/usr/bin/env bash
# post-test-generator.sh — Post-processing after the unified test generator runs.
#
# Actions:
#   1. Scan output for leaked secrets
#   2. Run compile gate on co-located Go tests (if SOURCE_REPO_DIR set)
#   3. Validate Python syntax (if Python tests generated)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

echo "::notice::Post test-generator: scanning output"

OUTPUT_DIR="$(find_last_output_dir)"
if [[ -z "${OUTPUT_DIR}" ]]; then
  echo "::error::No output directory found"
  exit 1
fi

scan_output_secrets "${OUTPUT_DIR}"

# --- Compile gate for co-located Go tests ---
if [[ -n "${SOURCE_REPO_DIR:-}" ]] && [[ -f "${SOURCE_REPO_DIR}/go.mod" ]]; then
  QF_GO_FILES=$(find "${SOURCE_REPO_DIR}" -name "qf_*_test.go" 2>/dev/null | head -20)
  if [[ -n "${QF_GO_FILES}" ]]; then
    echo "Running compile gate on co-located Go tests..."
    if (cd "${SOURCE_REPO_DIR}" && go test -run='^$' -count=1 ./... 2>&1); then
      echo "OK: compile gate passed"
    else
      echo "::warning::Compile gate failed — agent should have handled retries"
    fi
  fi
fi

# --- Syntax check for co-located Python tests ---
if [[ -n "${SOURCE_REPO_DIR:-}" ]]; then
  QF_PY_FILES=$(find "${SOURCE_REPO_DIR}" -name "qf_test_*.py" 2>/dev/null | head -20)
  if [[ -n "${QF_PY_FILES}" ]]; then
    echo "Running syntax check on co-located Python tests..."
    py_errors=0
    while IFS= read -r pyfile; do
      if python3 -m py_compile "${pyfile}" 2>&1; then
        echo "OK: ${pyfile}"
      else
        echo "::warning::Syntax error in ${pyfile}"
        py_errors=$((py_errors + 1))
      fi
    done <<< "${QF_PY_FILES}"
    if [[ "${py_errors}" -eq 0 ]]; then
      echo "OK: all Python tests pass syntax check"
    fi
  fi
fi

echo "Post test-generator complete."
