#!/usr/bin/env bash
# qa-deck.sh — the rules-based QA gate for the research-to-artifact loop.
#
# This is the evaluator step made deterministic. Wired as a Stop hook it answers
# "is the deck actually done?" and, if not, exits 2 and feeds the failures back so
# the loop keeps working. Per the dossier: rules ("every slide has speaker notes",
# "every claim cites a source", "every topic covered") beat LLM-as-judge for
# anything you can express as a check — faster, free, reproducible.
#
# Modes:
#   1) Stop-hook mode (no args): reads hook JSON on stdin, honors stop_hook_active,
#      QAs out/deck.json. Exit 0 = done, exit 2 = keep working (reasons on stderr).
#   2) File mode (one arg): QA a specific deck file. Exit 0/1. Used by the QA
#      subagent and tests.

set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

TOPICS_FILE="topics.md"

# Read topic slugs (first token before ' — ') from topics.md.
topic_slugs() {
  grep -E '^[a-z0-9-]+ +— ' "$TOPICS_FILE" | sed -E 's/ +— .*//'
}

qa_file() {
  local f="$1"
  local problems=()

  [ -f "$f" ] || { echo "deck file not found: $f"; return 1; }
  if ! jq empty "$f" 2>/dev/null; then echo "not valid JSON: $f"; return 1; fi

  # ---- structural checks (schema-equivalent, via jq) -------------------------
  while IFS= read -r line; do [ -n "$line" ] && problems+=("$line"); done < <(jq -r '
    [
      (if (.title|type)=="string" and (.title|length>=5) then empty else "title missing/too short" end),
      (if (.generated_for|type)=="string" then empty else "generated_for missing" end),
      (if (.slides|type)=="array" and (.slides|length>=5) then empty else "need >=5 slides" end),
      (if (.slides|length)<=30 then empty else "more than 30 slides" end),
      (if (any(.slides[]; .type=="title")) then empty else "no title slide" end),
      (if (any(.slides[]; .type=="summary")) then empty else "no summary slide" end),

      # EVERY slide must have speaker notes (the headline rule).
      (.slides[] | select((.speaker_notes|type)!="string" or (.speaker_notes|length)<30)
         | "slide \(.id // "?"): missing/short speaker_notes"),

      # EVERY content slide must have >=1 claim, and every claim a real source.
      (.slides[] | select(.type=="content")
         | select((.claims|type)!="array" or (.claims|length)==0)
         | "content slide \(.id // "?"): no claims"),
      (.slides[] | select(.type=="content") | .claims[]?
         | select((.source|type)!="string" or (.source|test("^https?://")|not))
         | "content slide claim has no valid source URL: \(.text[0:40])")
    ] | .[]' "$f" 2>/dev/null)

  # ---- coverage check: every topic from topics.md has a content slide ---------
  local covered
  covered="$(jq -r '[.slides[]|select(.type=="content")|.topic]|@tsv' "$f" 2>/dev/null || true)"
  while IFS= read -r slug; do
    [ -z "$slug" ] && continue
    if ! printf '%s' "$covered" | tr '\t' '\n' | grep -qx "$slug"; then
      problems+=("topic not covered by any slide: $slug")
    fi
  done < <(topic_slugs)

  if [ ${#problems[@]} -eq 0 ]; then return 0; fi
  printf '%s\n' "${problems[@]}"
  return 1
}

# ---- file mode ----------------------------------------------------------------
if [ "$#" -ge 1 ]; then
  if out=$(qa_file "$1"); then
    echo "QA PASS: $1"; exit 0
  else
    echo "QA FAIL: $1" >&2; echo "$out" | sed 's/^/  - /' >&2; exit 1
  fi
fi

# ---- stop-hook mode -----------------------------------------------------------
EVENT="$(cat 2>/dev/null || true)"
if [ -n "$EVENT" ] && [ "$(echo "$EVENT" | jq -r '.stop_hook_active // false' 2>/dev/null)" = "true" ]; then
  exit 0
fi

DECK="out/deck.json"
if [ ! -f "$DECK" ]; then
  echo "No deck at $DECK yet. Research the topics, assemble out/deck.json, then stop." >&2
  exit 2
fi
if out=$(qa_file "$DECK"); then
  exit 0
else
  { echo "Deck $DECK failed QA. Fix these before stopping:"; echo "$out" | sed 's/^/  - /'; } >&2
  exit 2
fi
