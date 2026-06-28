#!/usr/bin/env bash
# Validate that the STD builder produced expected output files.
# Expects: STD YAML + at least one stub file (Go or Python).
set -euo pipefail

OUTPUT_DIR="${1:-${FULLSEND_OUTPUT_DIR:-$(pwd)/output}}"
if [ ! -d "$OUTPUT_DIR" ]; then
    echo "FAIL: output directory not found: $OUTPUT_DIR"
    exit 1
fi

errors=0

# Check for STD YAML
std_files=$(find "$OUTPUT_DIR" -name "*_test_description.yaml" 2>/dev/null | wc -l)
if [ "$std_files" -eq 0 ]; then
    echo "FAIL: no *_test_description.yaml file found in $OUTPUT_DIR"
    errors=$((errors + 1))
else
    echo "OK: found $std_files STD YAML file(s)"
fi

# Check for stub files (Go or Python — at least one expected)
go_stubs=$(find "$OUTPUT_DIR" -name "*_stubs_test.go" 2>/dev/null | wc -l)
py_stubs=$(find "$OUTPUT_DIR" -name "test_*_stubs.py" 2>/dev/null | wc -l)
total_stubs=$((go_stubs + py_stubs))
if [ "$total_stubs" -eq 0 ]; then
    echo "WARN: no stub files found (non-fatal — stubs may be toggled off)"
else
    echo "OK: found $go_stubs Go stub(s), $py_stubs Python stub(s)"
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
