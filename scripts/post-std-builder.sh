#!/usr/bin/env bash
# post-std-builder.sh — Scan output for secrets after the std-builder agent runs.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

echo "::notice::Post std-builder: scanning output"

OUTPUT_DIR="$(find_last_output_dir)"
if [[ -z "${OUTPUT_DIR}" ]]; then
  echo "::error::No output directory found"
  exit 1
fi

scan_output_secrets "${OUTPUT_DIR}"
echo "Post std-builder complete."
