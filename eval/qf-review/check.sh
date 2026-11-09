#!/usr/bin/env bash
# check.sh — Pin the reviewer prompt's worked example to its schema.
#
# The example drifted twice during development (header counts disagreeing with
# the JSON below it, items shorter than total). It is the most-copied part of
# the prompt, so a broken example teaches the agent to break the same rule.
#
# Usage: ./check.sh [path/to/qualityflow-reviewer.md] [path/to/schema.json]
set -euo pipefail

PROMPT="${1:-$(cd "$(dirname "$0")/../.." && pwd)/agents/qualityflow-reviewer.md}"
SCHEMA="${2:-$(cd "$(dirname "$0")/../.." && pwd)/schemas/qf-review-result.schema.json}"

uv run --with jsonschema python - "$PROMPT" "$SCHEMA" <<'PY'
import json, re, sys
from jsonschema import Draft202012Validator

prompt, schema_path = sys.argv[1], sys.argv[2]
schema = json.load(open(schema_path))
Draft202012Validator.check_schema(schema)
v = Draft202012Validator(schema)
text = open(prompt).read()
fail = []

m = re.search(r"```json\n(.*?)\n```", text, re.S)
if not m:
    sys.exit("FAIL: no worked example found in the prompt")
ex = json.loads(m.group(1))

for e in v.iter_errors(ex):
    fail.append(f"example violates schema: {e.message}")

r, f = ex["requirements"], ex["findings"]
if r["total"] != r["covered"] + r["partial"] + r["uncovered"] + r["unimplemented"]:
    fail.append("example requirement counters do not sum to total")
if f["total"] != f["critical"] + f["major"] + f["minor"]:
    fail.append("example finding counters do not sum to total")
if len(f["items"]) != f["total"] - f.get("omitted", 0):
    fail.append("example findings.items count disagrees with total minus omitted")

# The markdown header above the example must agree with the JSON below it.
h = re.search(r"\*\*Verdict:\*\*.*?(\d+) critical, (\d+) major", text)
if not h:
    fail.append("no verdict header found in the example report")
elif (int(h.group(1)), int(h.group(2))) != (f["critical"], f["major"]):
    fail.append(f"example header says {h.group(1)}C/{h.group(2)}M, JSON says {f['critical']}C/{f['major']}M")

err = {"status": "error", "repo": "o/r", "pr_number": 1, "reason": "no-linked-work-item"}
if list(v.iter_errors(err)):
    fail.append("the Step 1 error result cannot validate against the schema")

print("\n".join("FAIL: " + x for x in fail) if fail else "PASS: prompt example and error path agree with the schema")
sys.exit(1 if fail else 0)
PY
