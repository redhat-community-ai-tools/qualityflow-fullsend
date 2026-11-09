#!/usr/bin/env bash
# collect.sh — Build an offline review bundle for one merged PR.
#
# Gathers exactly what the qualityflow-reviewer agent would see at runtime:
# the PR, its diff, and the work item it claims to close. Lets the agent's
# judgment be tested without FullSend, a sandbox, or a live PR.
#
# Usage: ./collect.sh owner/repo 7215 [outdir]
set -euo pipefail

REPO="${1:?usage: collect.sh owner/repo PR_NUMBER [outdir]}"
PR="${2:?usage: collect.sh owner/repo PR_NUMBER [outdir]}"
OUT="${3:-$(dirname "$0")/bundles}/${PR}"

mkdir -p "${OUT}"

gh pr view "${PR}" --repo "${REPO}" \
  --json number,title,body,author,mergedAt,files,additions,deletions \
  > "${OUT}/pr.json"

gh pr diff "${PR}" --repo "${REPO}" > "${OUT}/diff.patch"

# Work items this PR claims to close. The agent errors out when this is empty,
# so the bundle records that fact rather than hiding it.
grep -oiE '(fixes|closes|resolves) #[0-9]+' "${OUT}/pr.json" \
  | grep -oE '[0-9]+' | sort -u > "${OUT}/work-items.txt" || true

: > "${OUT}/work-items.md"
while read -r n; do
  [[ -z "${n}" ]] && continue
  {
    echo "## Issue #${n}"
    gh issue view "${n}" --repo "${REPO}" --json title,body,labels \
      --jq '"**" + .title + "**\n\nLabels: " + ([.labels[].name] | join(", ")) + "\n\n" + .body'
    echo
  } >> "${OUT}/work-items.md"
done < "${OUT}/work-items.txt"

python3 - "${OUT}/pr.json" > "${OUT}/files.txt" <<'PY'
import json, sys
for f in json.load(open(sys.argv[1]))["files"]:
    print(f"{f['path']}\t+{f['additions']}/-{f['deletions']}")
PY

echo "bundle: ${OUT}"
wc -l "${OUT}/diff.patch" "${OUT}/work-items.md" "${OUT}/files.txt" | tail -4
