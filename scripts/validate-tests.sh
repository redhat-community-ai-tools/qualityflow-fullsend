#!/usr/bin/env bash
# validate-tests.sh — Validate that the test generator produced expected output.
# Language-agnostic: detects test files by common naming conventions across all languages.
set -euo pipefail

OUTPUT_DIR="${1:-${FULLSEND_OUTPUT_DIR:-$(pwd)/output}}"

if [ ! -d "$OUTPUT_DIR" ]; then
    mkdir -p "$OUTPUT_DIR"
fi

TEST_PATTERNS=(
    -name "*_test.go"
    -o -name "test_*.py"
    -o -name "*_test.py"
    -o -name "*Test.java"
    -o -name "*_test.rs"
    -o -name "*.test.ts"
    -o -name "*.spec.ts"
    -o -name "*.test.js"
    -o -name "*.spec.js"
    -o -name "*_test.rb"
    -o -name "*_spec.rb"
    -o -name "*_test.cpp"
    -o -name "*_test.c"
    -o -name "test_*.*"
    -o -name "*_test.*"
)

count_tests() {
    find "$1" -type f \( "${TEST_PATTERNS[@]}" \) 2>/dev/null | wc -l | tr -d ' '
}

list_tests() {
    find "$1" -type f \( "${TEST_PATTERNS[@]}" \) 2>/dev/null
}

total_tests=$(count_tests "$OUTPUT_DIR")

# --- Check for co-located qf_ prefixed tests in source repo ---
qf_colocated_count=0
if [ -n "${SOURCE_REPO_DIR:-}" ] && [ -d "${SOURCE_REPO_DIR}" ]; then
    qf_colocated_count=$(find "${SOURCE_REPO_DIR}" \( -name "qf_*_test.go" -o -name "qf_test_*.py" \) 2>/dev/null | wc -l | tr -d ' ')
    if [ "$qf_colocated_count" -gt 0 ]; then
        echo "OK: found ${qf_colocated_count} co-located qf-prefixed test file(s) in source repo"
        total_tests=$((total_tests + qf_colocated_count))
    fi
fi

# --- Fallback: check sandbox workspace if nothing in OUTPUT_DIR ---
if [ "$total_tests" -eq 0 ]; then
    for search_root in /sandbox/workspace/pr-repo/outputs /sandbox/workspace/target-repo/outputs; do
        if [ -d "$search_root" ]; then
            fallback_count=$(count_tests "$search_root")
            if [ "$fallback_count" -gt 0 ]; then
                echo "Found $fallback_count test file(s) in $search_root — copying to output"
                find "$search_root" -type f \( "${TEST_PATTERNS[@]}" \) -exec cp --parents {} "$OUTPUT_DIR/" \; 2>/dev/null || \
                    find "$search_root" -type f \( "${TEST_PATTERNS[@]}" \) -print0 2>/dev/null | while IFS= read -r -d '' f; do
                        rel="${f#"$search_root"/}"
                        mkdir -p "$OUTPUT_DIR/$(dirname "$rel")"
                        cp "$f" "$OUTPUT_DIR/$rel"
                    done
                total_tests=$(count_tests "$OUTPUT_DIR")
                break
            fi
        fi
    done
fi

# --- Report per-language breakdown ---
if [ "$total_tests" -gt 0 ]; then
    declare -A lang_counts
    while IFS= read -r file; do
        case "$file" in
            *_test.go)            lang="Go" ;;
            *test_*.py|*_test.py) lang="Python" ;;
            *Test.java)           lang="Java" ;;
            *_test.rs)            lang="Rust" ;;
            *.test.ts|*.spec.ts)  lang="TypeScript" ;;
            *.test.js|*.spec.js)  lang="JavaScript" ;;
            *_test.rb|*_spec.rb)  lang="Ruby" ;;
            *_test.cpp|*_test.c)  lang="C/C++" ;;
            *)                    lang="Other" ;;
        esac
        lang_counts[$lang]=$(( ${lang_counts[$lang]:-0} + 1 ))
    done < <(list_tests "$OUTPUT_DIR")

    breakdown=""
    for lang in "${!lang_counts[@]}"; do
        echo "OK: found ${lang_counts[$lang]} $lang test file(s)"
        breakdown="${breakdown:+$breakdown, }$lang: ${lang_counts[$lang]}"
    done
fi

# --- Check for summary ---
if [ -f "$OUTPUT_DIR/summary.yaml" ]; then
    echo "OK: summary.yaml found"
else
    echo "WARN: summary.yaml not found (non-fatal)"
fi

# --- Optional compile gate for co-located Go tests ---
compile_status="skipped"
if [ "$qf_colocated_count" -gt 0 ] && [ -n "${SOURCE_REPO_DIR:-}" ] && [ -f "${SOURCE_REPO_DIR}/go.mod" ]; then
    echo "Running compile gate on co-located Go tests..."
    if (cd "${SOURCE_REPO_DIR}" && go test -run='^$' -count=1 ./... 2>&1); then
        echo "OK: compile gate passed"
        compile_status="passed"
    else
        echo "WARN: compile gate failed (non-fatal during validation)"
        compile_status="failed"
    fi
fi

# --- Final verdict ---
if [ "$total_tests" -eq 0 ]; then
    echo "FAIL: no test files found in output"
    exit 1
fi

echo "PASS: output validated — $total_tests test file(s) ($breakdown), compile gate: $compile_status"
