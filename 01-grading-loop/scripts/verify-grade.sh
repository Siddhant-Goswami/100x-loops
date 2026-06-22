#!/usr/bin/env bash
# verify-grade.sh — the rules-based completion gate for the grading loop.
#
# This is the load-bearing loop primitive. Wired as a Stop hook, it answers one
# question: "is there a valid grade yet?" If not, it exits 2 and feeds the reason
# back to Claude, which FORCES the loop to keep working. Rules-based checks (jq,
# schema) are deterministic and ~free — far more reliable than asking another LLM
# "is this grade good?".
#
# Two modes:
#   1) Stop-hook mode  (no args): reads the hook's JSON event on stdin, honors
#      stop_hook_active to avoid infinite loops, finds the newest grade file.
#   2) File mode       (one arg): validate a specific grade file. Used by the
#      verifier subagent and by tests. Always exits 0/1 (never 2) in this mode.
#
# Exit codes:
#   0 = valid grade present            -> loop may stop / file is OK
#   2 = (stop-hook mode) NOT done yet  -> Claude keeps working (reason on stderr)
#   1 = (file mode) file invalid

set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# ---- validate one grade file; prints problems to stdout; returns 0/1 ----------
validate_file() {
  local f="$1"
  local problems=()

  [ -f "$f" ] || { echo "grade file not found: $f"; return 1; }
  if ! jq empty "$f" 2>/dev/null; then
    echo "not valid JSON: $f"; return 1
  fi

  # Required top-level fields + enums + ranges, expressed as jq assertions.
  local checks='
    def fail(m): m;
    [
      (if (.submission_id|type)=="string" and (.submission_id|length>0) then empty else "submission_id missing/empty" end),
      (if (.reasoning|type)=="string" and (.reasoning|length>=20) then empty else "reasoning missing or <20 chars" end),
      (if (.confidence|type)=="number" and .confidence>=0 and .confidence<=1 then empty else "confidence missing or out of [0,1]" end),
      (if (.needs_human_review|type)=="boolean" then empty else "needs_human_review missing/not boolean" end),
      (if (.overall|IN("pass","partial","fail")) then empty else "overall not in pass|partial|fail" end),
      (if (.criteria|type)=="object" then empty else "criteria missing" end),
      (["correctness","completeness","clarity"][] as $k
        | if (.criteria[$k]) == null then "criteria.\($k) missing"
          elif (.criteria[$k].level|IN("pass","partial","fail")|not) then "criteria.\($k).level invalid"
          elif ((.criteria[$k].evidence|type)!="string" or (.criteria[$k].evidence|length<10)) then "criteria.\($k).evidence missing/<10 chars"
          else empty end)
    ]'
  while IFS= read -r line; do
    [ -n "$line" ] && problems+=("$line")
  done < <(jq -r "$checks | .[]" "$f" 2>/dev/null)

  # Cross-field rule: overall must follow the rubric verdict mapping.
  local consistent
  consistent=$(jq -r '
    (.criteria.correctness.level)  as $c
  | (.criteria.completeness.level) as $p
  | (.criteria.clarity.level)      as $l
  | (if   ($c=="fail" or $p=="fail")               then "fail"
     elif ($c=="pass" and $p=="pass" and $l!="fail") then "pass"
     else "partial" end) as $expected
  | if .overall==$expected then "ok" else "overall=\(.overall) but rubric mapping implies \($expected)" end
  ' "$f" 2>/dev/null || echo "could not evaluate mapping")
  [ "$consistent" = "ok" ] || problems+=("$consistent")

  if [ ${#problems[@]} -eq 0 ]; then
    return 0
  fi
  printf '%s\n' "${problems[@]}"
  return 1
}

# ---- file mode ----------------------------------------------------------------
if [ "$#" -ge 1 ]; then
  if out=$(validate_file "$1"); then
    echo "OK: $1 is a valid grade."
    exit 0
  else
    echo "INVALID: $1" >&2
    echo "$out" | sed 's/^/  - /' >&2
    exit 1
  fi
fi

# ---- stop-hook mode -----------------------------------------------------------
EVENT="$(cat 2>/dev/null || true)"
# Infinite-loop guard: if we already blocked once this turn, let it stop.
if [ -n "$EVENT" ] && [ "$(echo "$EVENT" | jq -r '.stop_hook_active // false' 2>/dev/null)" = "true" ]; then
  exit 0
fi

newest="$(ls -t out/*.grade.json 2>/dev/null | head -n1 || true)"
if [ -z "$newest" ]; then
  echo "No grade file found in out/. Grade the submission and write out/<id>.grade.json before stopping." >&2
  exit 2
fi

if out=$(validate_file "$newest"); then
  exit 0
else
  {
    echo "The grade $newest is not rubric/schema compliant. Fix these and re-write it before stopping:"
    echo "$out" | sed 's/^/  - /'
  } >&2
  exit 2
fi
