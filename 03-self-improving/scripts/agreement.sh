#!/usr/bin/env bash
# agreement.sh — how often does the machine grade match the instructor?
#
# This is the metric the meta-loop is trying to move. If calibration works, the
# agreement rate should climb over successive terms as corrections feed back in.
#
# Usage: agreement.sh

set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; cd "$ROOT"
f="calibration/decisions.jsonl"
[ -f "$f" ] || { echo "no decisions recorded yet ($f)"; exit 0; }

total=$(grep -c . "$f" || true)
agreed=$(jq -s '[.[]|select(.agreed)]|length' "$f")
rate=$(awk "BEGIN{ if($total>0) printf \"%.0f\", 100*$agreed/$total; else print 0 }")

echo "machine vs instructor agreement: $agreed/$total = ${rate}%"
echo "open corrections (drive calibration):"
jq -r 'select(.agreed|not) | "  - [\(.submission_id)] \(.machine_overall) -> \(.human_overall): \(.lesson)"' "$f"

if [ -f calibration/agreement-history.jsonl ]; then
  echo "history (after each learn.sh apply):"
  jq -r '"  \(.applied)  n=\(.n)  agreement=\(.rate)%"' calibration/agreement-history.jsonl
fi
