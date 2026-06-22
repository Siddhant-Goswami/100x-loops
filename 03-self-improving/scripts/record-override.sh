#!/usr/bin/env bash
# record-override.sh — an instructor logs one adjudicated case.
#
# This is the human-in-the-loop feeding the meta-loop. Every time an instructor
# reviews a machine grade (e.g. from Loop 01's review-queue) and confirms or
# corrects it, that decision is recorded here. Agreements AND corrections both
# go in, so we can measure how often the machine matches the human over time.
#
# Usage:
#   record-override.sh <submission_id> <machine_overall> <human_overall> "<lesson>"
# Example (a correction):
#   record-override.sh carol partial pass "implicit termination still satisfies (c)"
# Example (an agreement — lesson optional):
#   record-override.sh bob fail fail ""

set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; cd "$ROOT"
mkdir -p calibration

id="${1:?need submission_id}"
machine="${2:?need machine_overall}"
human="${3:?need human_overall}"
lesson="${4:-}"
ts="$(date +%Y-%m-%d)"

jq -nc --arg id "$id" --arg m "$machine" --arg h "$human" --arg l "$lesson" --arg ts "$ts" '
  { submission_id:$id, machine_overall:$m, human_overall:$h,
    agreed: ($m==$h), lesson:$l, recorded:$ts }' >> calibration/decisions.jsonl

if [ "$machine" = "$human" ]; then
  echo "recorded agreement: [$id] $machine"
else
  echo "recorded CORRECTION: [$id] machine=$machine -> human=$human"
fi
