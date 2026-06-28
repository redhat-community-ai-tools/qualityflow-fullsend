#!/usr/bin/env bash
set -euo pipefail

# Compute the base: URL with SHA256 integrity hash for a QualityFlow
# harness file at a given commit.
#
# Usage:
#   ./scripts/compute-integrity.sh <commit-sha> [harness-file]
#
# Examples:
#   ./scripts/compute-integrity.sh abc123def456
#   ./scripts/compute-integrity.sh abc123def456 harness/stp-builder.yaml
#
# The default harness file is harness/qualityflow.yaml.

COMMIT_SHA="${1:?Usage: $0 <commit-sha> [harness-file]}"
HARNESS_FILE="${2:-harness/qualityflow.yaml}"

REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")

if [[ -z "${REMOTE_URL}" ]]; then
    echo "Error: not in a git repo or no remote configured" >&2
    exit 1
fi

REPO_PATH=$(echo "${REMOTE_URL}" | sed -n 's|.*github\.com[:/]\(.*\)\.git|\1|p')
if [[ -z "${REPO_PATH}" ]]; then
    REPO_PATH=$(echo "${REMOTE_URL}" | sed -n 's|.*github\.com[:/]\(.*\)|\1|p')
fi

RAW_URL="https://raw.githubusercontent.com/${REPO_PATH}/${COMMIT_SHA}/${HARNESS_FILE}"

HASH=$(git show "${COMMIT_SHA}:${HARNESS_FILE}" 2>/dev/null | shasum -a 256 | cut -d' ' -f1)

if [[ -z "${HASH}" ]]; then
    echo "Error: could not read ${HARNESS_FILE} at commit ${COMMIT_SHA}" >&2
    echo "  Make sure the commit exists and the file path is correct." >&2
    exit 1
fi

echo ""
echo "Harness: ${HARNESS_FILE}"
echo "Commit:  ${COMMIT_SHA}"
echo "Hash:    sha256=${HASH}"
echo ""
echo "base: ${RAW_URL}#sha256=${HASH}"
echo ""
