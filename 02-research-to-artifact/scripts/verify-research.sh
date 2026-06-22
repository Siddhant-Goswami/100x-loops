#!/usr/bin/env bash
# verify-research.sh — gate for ONE topic's research (the inner verify step of
# the research stage). Checks the worker's output before it is allowed into the
# deck: >=3 key points, every point sourced with a real URL, headline + takeaway.
#
# Usage: verify-research.sh out/research/<slug>.json   (exit 0 ok / 1 invalid)

set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; cd "$ROOT"
f="${1:?usage: verify-research.sh <research.json>}"

[ -f "$f" ] || { echo "missing: $f" >&2; exit 1; }
jq empty "$f" 2>/dev/null || { echo "not JSON: $f" >&2; exit 1; }

problems=$(jq -r '
  [
    (if (.topic|type)=="string" then empty else "topic missing" end),
    (if (.headline|type)=="string" and (.headline|length>=15) then empty else "headline missing/short" end),
    (if (.takeaway|type)=="string" and (.takeaway|length>=15) then empty else "takeaway missing/short" end),
    (if (.key_points|type)=="array" and (.key_points|length>=3) then empty else "need >=3 key_points" end),
    (.key_points[]? | select((.source|type)!="string" or (.source|test("^https?://")|not))
      | "key_point without valid source: \(.text[0:40])")
  ] | .[]' "$f" 2>/dev/null)

if [ -z "$problems" ]; then
  echo "OK: $f"; exit 0
else
  echo "INVALID: $f" >&2; echo "$problems" | sed 's/^/  - /' >&2; exit 1
fi
