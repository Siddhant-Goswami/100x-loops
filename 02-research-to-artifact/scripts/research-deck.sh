#!/usr/bin/env bash
# research-deck.sh — the research-to-artifact loop, end to end.
#
# Orchestrator-worker + evaluator-optimizer:
#
#   read topics.md
#   PARALLEL: research each topic    (workers, fanned out with &)   ← parallelization
#     verify each topic's research   (inner gate, retry up to MAX_ITERS)
#   assemble deck.json + slides.md   (content/slide/notes generation)
#   QA loop: qa-deck.sh              (evaluator)                    ← evaluator-optimizer
#     fail -> regenerate, retry up to MAX_ITERS
#   render final artifacts
#
# Usage:
#   RESEARCHER=mock   ./scripts/research-deck.sh        # offline, deterministic
#   RESEARCHER=claude ./scripts/research-deck.sh        # real research via claude -p
#
# Env: RESEARCHER=mock|claude  MAX_ITERS=3  TITLE="..."  AUDIENCE="..."

set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; cd "$ROOT"

RESEARCHER="${RESEARCHER:-mock}"
MAX_ITERS="${MAX_ITERS:-3}"
TITLE="${TITLE:-State of Agentic AI}"
AUDIENCE="${AUDIENCE:-100x cohort — loop engineering}"

mkdir -p out/research
rm -f out/research/*.json out/deck.json out/slides.md out/speaker-notes.md 2>/dev/null || true

SLUGS=()
while IFS= read -r s; do [ -n "$s" ] && SLUGS+=("$s"); done \
  < <(grep -E '^[a-z0-9-]+ +— ' topics.md | sed -E 's/ +— .*//')
echo "== research-to-artifact loop ==  researcher=$RESEARCHER  topics=${#SLUGS[@]}  max_iters=$MAX_ITERS"

# ---- one topic: research + verify, bounded retry ------------------------------
research_one() {
  local slug="$1" rf="out/research/$1.json"
  for ((i=1; i<=MAX_ITERS; i++)); do
    if [ "$RESEARCHER" = "claude" ]; then
      claude -p "/research-topic $slug" --allowedTools "WebSearch,WebFetch,Write,Read" --output-format json >/dev/null 2>&1 || true
    else
      ./scripts/mock-researcher.sh "$slug" >/dev/null
    fi
    if ./scripts/verify-research.sh "$rf" >/dev/null 2>&1; then
      echo "  [research:$slug] ok (iter $i)"; return 0
    fi
    echo "  [research:$slug] invalid, retry $i" >&2
  done
  echo "  [research:$slug] FAILED after $MAX_ITERS" >&2; return 1
}

# ---- STAGE 1: parallel fan-out across topics (the parallelization pattern) -----
echo "-- stage 1: parallel research --"
pids=(); fail=0
for slug in "${SLUGS[@]}"; do
  research_one "$slug" &
  pids+=($!)
done
for pid in "${pids[@]}"; do wait "$pid" || fail=1; done
if [ "$fail" -ne 0 ]; then
  echo "!! one or more topics failed research — aborting before assembly." >&2
  exit 1
fi

# ---- STAGE 2 + 3: assemble, then QA-in-a-loop ---------------------------------
echo "-- stage 2/3: assemble + QA loop --"
qa_ok=0
for ((i=1; i<=MAX_ITERS; i++)); do
  ./scripts/build-deck.sh "$TITLE" "$AUDIENCE" >/dev/null
  if out=$(./scripts/qa-deck.sh out/deck.json 2>&1); then
    echo "  [qa] PASS (iter $i)"; qa_ok=1; break
  fi
  echo "  [qa] fail (iter $i):" >&2; echo "$out" | sed 's/^/    /' >&2
  # In real mode you'd re-invoke the deck-writer subagent with the QA feedback
  # here. The deterministic builder is idempotent, so we just bound the attempts.
done

if [ "$qa_ok" -ne 1 ]; then
  echo "!! deck failed QA after $MAX_ITERS iterations — not shipping. A human should review out/deck.json." >&2
  exit 1
fi

echo "== done =="
echo "   deck:          out/deck.json   ($(jq '.slides|length' out/deck.json) slides)"
echo "   slides:        out/slides.md"
echo "   speaker notes: out/speaker-notes.md"
echo "   every slide has notes ✓   every claim is sourced ✓   every topic covered ✓"
