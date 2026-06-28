#!/usr/bin/env bash
# Validate that a review agent produced expected output files.
# Works for both STP review and STP refiner (both produce *_review.md).
set -euo pipefail

OUTPUT_DIR="${1:-${FULLSEND_OUTPUT_DIR:-$(pwd)/output}}"
if [ ! -d "$OUTPUT_DIR" ]; then
    echo "FAIL: output directory not found: $OUTPUT_DIR"
    exit 1
fi

errors=0

# Check for review markdown (STP or STD review report)
review_files=$(find "$OUTPUT_DIR" -name "*_review.md" -o -name "*_refinement_log.md" 2>/dev/null | wc -l)
if [ "$review_files" -eq 0 ]; then
    echo "FAIL: no *_review.md or *_refinement_log.md file found in $OUTPUT_DIR"
    errors=$((errors + 1))
else
    echo "OK: found $review_files review/refinement file(s)"
fi

# Check for summary
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
