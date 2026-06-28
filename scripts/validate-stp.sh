#!/usr/bin/env bash
# Validate that the STP builder produced expected output files.
# FullSend sets cwd to the iteration dir (e.g. .../iteration-1/)
# and output files live in ./output/ beneath it.
# Also accepts $1 or FULLSEND_OUTPUT_DIR as overrides.
set -euo pipefail

OUTPUT_DIR="${1:-${FULLSEND_OUTPUT_DIR:-$(pwd)/output}}"
if [ ! -d "$OUTPUT_DIR" ]; then
    echo "FAIL: output directory not found: $OUTPUT_DIR"
    exit 1
fi

errors=0

# Check for the STP markdown file
stp_files=$(find "$OUTPUT_DIR" -name "*_test_plan.md" 2>/dev/null | wc -l)
if [ "$stp_files" -eq 0 ]; then
    echo "FAIL: no *_test_plan.md file found in $OUTPUT_DIR"
    errors=$((errors + 1))
else
    echo "OK: found $stp_files STP file(s)"
fi

# Check for the summary file
if [ -f "$OUTPUT_DIR/summary.yaml" ]; then
    echo "OK: summary.yaml found"
else
    echo "WARN: summary.yaml not found (non-fatal)"
fi

if [ "$errors" -gt 0 ]; then
    echo "FAIL: $errors validation error(s)"
    exit 1
fi

echo "PASS: output validated"
