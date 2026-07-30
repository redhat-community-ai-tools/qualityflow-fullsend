#!/usr/bin/env bash
set -euo pipefail

# Sync vendored qualityflow content from the upstream repo.
#
# Usage:
#   ./scripts/sync-qualityflow.sh                    # sync to latest main
#   ./scripts/sync-qualityflow.sh <commit-or-branch>  # sync to specific ref
#
# This replaces agents/, skills/, config/, and commands/ under qualityflow/
# with content from the upstream qualityflow repository. The previous
# content is removed before copying to ensure deleted files are cleaned up.
#
# After running, review the diff and commit the changes.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
VENDOR_DIR="${REPO_ROOT}/qualityflow"
UPSTREAM_REPO="https://github.com/redhat-community-ai-tools/qualityflow.git"
TARGET_REF="${1:-main}"

DIRS_TO_SYNC=(agents skills config commands)

TMPDIR=$(mktemp -d)
trap 'rm -rf "${TMPDIR}"' EXIT

echo "Cloning qualityflow at ref: ${TARGET_REF}..."
if ! git clone --depth 1 --branch "${TARGET_REF}" "${UPSTREAM_REPO}" "${TMPDIR}/qualityflow" 2>/dev/null; then
    echo "  Branch not found, trying as commit SHA..."
    git clone "${UPSTREAM_REPO}" "${TMPDIR}/qualityflow" 2>/dev/null
    (cd "${TMPDIR}/qualityflow" && git checkout "${TARGET_REF}" 2>/dev/null)
fi

COMMIT_SHA=$(cd "${TMPDIR}/qualityflow" && git rev-parse HEAD)
echo "Upstream commit: ${COMMIT_SHA}"

for dir in "${DIRS_TO_SYNC[@]}"; do
    if [[ ! -d "${TMPDIR}/qualityflow/${dir}" ]]; then
        echo "Warning: ${dir}/ not found in upstream repo, skipping"
        continue
    fi
    rm -rf "${VENDOR_DIR}/${dir}"
    cp -r "${TMPDIR}/qualityflow/${dir}" "${VENDOR_DIR}/${dir}"
    echo "  Synced: ${dir}/"
done

cat > "${VENDOR_DIR}/.qualityflow-source" <<EOF
# This directory is vendored from the qualityflow repo.
# Do not edit files here directly. Run scripts/sync-qualityflow.sh to update.
repo: ${UPSTREAM_REPO%.git}
commit: ${COMMIT_SHA}
synced_at: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
directories:
$(for dir in "${DIRS_TO_SYNC[@]}"; do echo "  - ${dir}"; done)
EOF

echo ""
echo "Vendored qualityflow at ${COMMIT_SHA}"
echo "Review changes with 'git diff', then commit."
