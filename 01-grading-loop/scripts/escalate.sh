#!/usr/bin/env bash
# escalate.sh — the confidence/escalation gate.
#
# Takes a valid grade file and decides: auto-clear, or route to a human?
# This is what makes the loop worth running: the instructor only ever looks at
# the genuinely uncertain cases, not the whole class.
#
# Usage: escalate.sh out/<id>.grade.json [threshold]
# Prints "AUTO" or "REVIEW <reason>". On REVIEW, copies the grade into
# review-queue/ for the instructor.

set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

f="${1:?usage: escalate.sh <grade.json> [threshold]}"
THRESHOLD="${2:-0.75}"

read -r flag conf overall id < <(jq -r '
  [(.needs_human_review), (.confidence), (.overall), (.submission_id)] | @tsv' "$f" | tr '\t' ' ')

reason=""
if [ "$flag" = "true" ]; then
  reason="grader flagged needs_human_review"
elif awk "BEGIN{exit !($conf < $THRESHOLD)}"; then
  reason="confidence $conf < threshold $THRESHOLD"
fi

mkdir -p review-queue
if [ -n "$reason" ]; then
  cp "$f" "review-queue/$(basename "$f")"
  echo "REVIEW [$id] overall=$overall conf=$conf — $reason"
  exit 0
else
  echo "AUTO   [$id] overall=$overall conf=$conf — cleared without human review"
  exit 0
fi
