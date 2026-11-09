#!/usr/bin/env bash
# post-qf-review.sh — Post the QualityFlow QE review as a sticky PR comment.
#
# Runs on the runner after the sandbox is destroyed. CWD is the run dir.
# The agent is read-only; this script is the only thing that writes anywhere,
# and all it writes is one comment.
#
# Required env vars:
#   REPO_FULL_NAME — owner/repo
#   PR_NUMBER      — pull request number
#   GH_TOKEN       — token with pull-requests:write on the target repo
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

MARKER='<!-- fullsend:qualityflow-reviewer -->'

echo "::notice::Post qf-review: ${REPO_FULL_NAME:-unset}#${PR_NUMBER:-unset}"

require_env REPO_FULL_NAME PR_NUMBER GH_TOKEN

OUTPUT_DIR="$(find_last_output_dir)"
if [[ -z "${OUTPUT_DIR}" ]]; then
  echo "::error::No output directory found"
  exit 1
fi

scan_output_secrets "${OUTPUT_DIR}"

RESULT_FILE="${OUTPUT_DIR}/agent-result.json"
if [[ ! -f "${RESULT_FILE}" ]]; then
  echo "::error::${RESULT_FILE} not found — nothing to post"
  exit 1
fi

STATUS="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("status",""))' "${RESULT_FILE}")"
if [[ "${STATUS}" == "error" ]]; then
  REASON="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("reason","unknown"))' "${RESULT_FILE}")"
  echo "::warning::Review did not complete (${REASON}) — no comment posted"
  exit 0
fi

REPORT_NAME="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("report","qf_review.md"))' "${RESULT_FILE}")"
REPORT="${OUTPUT_DIR}/$(basename "${REPORT_NAME}")"
if [[ ! -f "${REPORT}" ]]; then
  echo "::error::Report ${REPORT} not found"
  exit 1
fi

if ! command -v fullsend >/dev/null 2>&1; then
  echo "::error::fullsend CLI not on PATH — cannot post sticky comment"
  exit 1
fi

# Sticky comment, not a formal review: this agent advises, it does not gate
# merges. Its own marker keeps it from overwriting the code review's comment.
fullsend issues post-comment \
  --tracker github \
  --project "${REPO_FULL_NAME}" \
  --number "${PR_NUMBER}" \
  --marker "${MARKER}" \
  --result "${REPORT}"

VERDICT="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("verdict",""))' "${RESULT_FILE}")"
echo "::notice::QualityFlow QE review posted: ${VERDICT}"
