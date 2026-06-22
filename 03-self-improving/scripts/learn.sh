#!/usr/bin/env bash
# learn.sh — the meta-loop step: the system improves its OWN rubric.
#
# Reads the instructor's corrections, turns each into a few-shot calibration
# example, and rewrites the AUTO-CALIBRATION block in rubric.md so the next
# grading run has already seen where the last one was wrong.
#
# SAFETY — the whole reason this is the LAST loop:
#   * It only ever edits text BETWEEN the managed markers in rubric.md. It cannot
#     touch the base rubric, the verdict mapping, or anything outside the block.
#   * It is a PROPOSAL by default. Nothing is written to rubric.md unless the
#     instructor re-runs with APPROVE=1. A self-modifying loop never applies to a
#     real resource without a human saying yes.
#
# Usage:
#   ./scripts/learn.sh             # propose only -> calibration/proposed-calibration.md
#   APPROVE=1 ./scripts/learn.sh   # apply the proposal into rubric.md

set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; cd "$ROOT"
DEC="calibration/decisions.jsonl"
RUBRIC="rubric.md"
PROPOSAL="calibration/proposed-calibration.md"
BEGIN="<!-- BEGIN AUTO-CALIBRATION (managed by scripts/learn.sh — do not hand-edit) -->"
END="<!-- END AUTO-CALIBRATION -->"

[ -f "$DEC" ] || { echo "no corrections to learn from ($DEC). Record some with record-override.sh first."; exit 0; }

total=$(grep -c . "$DEC" || true)
agreed=$(jq -s '[.[]|select(.agreed)]|length' "$DEC")
corrections=$(jq -s '[.[]|select(.agreed|not)]|length' "$DEC")
rate=$(awk "BEGIN{ if($total>0) printf \"%.0f\", 100*$agreed/$total; else print 0 }")

# ---- build the new calibration block from the corrections --------------------
{
  echo "$BEGIN"
  echo "_Auto-generated from $corrections instructor correction(s) across $total adjudicated cases (agreement ${rate}%). Last updated $(date +%Y-%m-%d)._"
  echo
  if [ "$corrections" -eq 0 ]; then
    echo "_No corrections on record — the grader currently matches the instructor on every case._"
  else
    echo "When grading, treat these past corrections as binding precedent:"
    echo
    jq -r 'select(.agreed|not)
      | "- **\(.submission_id)** — the grader said `\(.machine_overall)`, the instructor said `\(.human_overall)`."
      + (if (.lesson|length)>0 then "\n  - Lesson: \(.lesson)" else "" end)' "$DEC"
  fi
  echo "$END"
} > calibration/_newblock.md

# ---- assemble the proposed rubric (base rubric + new block) ------------------
awk -v begin="$BEGIN" -v end="$END" -v blockfile="calibration/_newblock.md" '
  $0==begin {inblock=1; while ((getline line < blockfile)>0) print line; next}
  $0==end {inblock=0; next}
  !inblock {print}
' "$RUBRIC" > "$PROPOSAL"
rm -f calibration/_newblock.md

echo "== meta-loop: learn =="
echo "  adjudicated: $total   agreement: ${rate}%   corrections to encode: $corrections"

if [ "${APPROVE:-0}" = "1" ]; then
  cp "$PROPOSAL" "$RUBRIC"
  jq -nc --arg ts "$(date +%Y-%m-%dT%H:%M:%S)" --argjson n "$total" --argjson rate "$rate" \
    '{applied:$ts, n:$n, rate:$rate}' >> calibration/agreement-history.jsonl
  echo "  APPLIED -> rubric.md updated (calibration block rewritten). Logged to agreement-history.jsonl."
else
  echo "  PROPOSAL written -> $PROPOSAL"
  echo "  Review it, then re-run with APPROVE=1 to apply. (Nothing changed yet.)"
fi
