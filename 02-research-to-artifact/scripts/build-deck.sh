#!/usr/bin/env bash
# build-deck.sh — the content/slide/speaker-notes generation step.
#
# Deterministically assembles verified per-topic research into the final artifact:
#   out/deck.json          — structured deck (the source of truth, QA'd)
#   out/slides.md          — Marp-style rendered slides (--- between slides)
#   out/speaker-notes.md   — per-topic speaker notes for the lecturer
#
# In real mode the deck-writer subagent does this with editorial judgment; this
# deterministic builder lets the whole loop run offline and gives the QA gate a
# real artifact to check. Assembly order: title -> one content slide per topic
# (in topics.md order) -> summary.
#
# Usage: build-deck.sh "<deck title>" "<generated_for>"

set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; cd "$ROOT"

TITLE="${1:-State of Agentic AI}"
AUDIENCE="${2:-100x cohort}"

# Ordered topic slugs + titles from topics.md
LINES=()
while IFS= read -r l; do [ -n "$l" ] && LINES+=("$l"); done \
  < <(grep -E '^[a-z0-9-]+ +— ' topics.md)

# Build a JSON array of content slides from each topic's research file.
content_slides='[]'
for line in "${LINES[@]}"; do
  slug="${line%% —*}"; slug="${slug// /}"
  title="${line#*— }"
  rf="out/research/${slug}.json"
  [ -f "$rf" ] || { echo "missing research for $slug ($rf)" >&2; exit 1; }

  slide=$(jq -c --arg slug "$slug" --arg title "$title" '
    {
      id: ("slide-" + $slug),
      type: "content",
      heading: $title,
      topic: $slug,
      bullets: [ .key_points[].text ],
      claims: [ .key_points[] | { text: .text, source: .source } ],
      speaker_notes: ( .headline + " — " + .takeaway )
    }' "$rf")
  content_slides=$(jq -c --argjson s "$slide" '. + [$s]' <<<"$content_slides")
done

# Title slide + content slides + summary slide.
summary_notes="Recap the through-line: every topic here is an instance of the same loop — sense, act, verify, repeat. Tie back to why the machine owning the loop is the whole shift."
jq -n \
  --arg title "$TITLE" \
  --arg audience "$AUDIENCE" \
  --argjson content "$content_slides" \
  --arg snotes "$summary_notes" '
  {
    title: $title,
    generated_for: $audience,
    slides: (
      [ { id:"title", type:"title", heading:$title, topic:null,
          bullets:[$audience], speaker_notes:("Open the lecture. Audience: " + $audience + ". Set up that today is one idea seen from three angles.") } ]
      + $content
      + [ { id:"summary", type:"summary", heading:"Takeaways", topic:null,
            bullets: [ $content[].heading ], speaker_notes:$snotes } ]
    )
  }' > out/deck.json

# ---- render slides.md (Marp-style) -------------------------------------------
{
  echo "---"; echo "marp: true"; echo "---"; echo
  jq -r '.slides[] |
    "# \(.heading)\n",
    ( .bullets[]? | "- \(.)" ),
    "",
    ( if (.claims|length)>0 then "Sources: " + ([.claims[].source]|join(", ")) else empty end ),
    "\n---\n"' out/deck.json
} > out/slides.md

# ---- render speaker-notes.md -------------------------------------------------
{
  echo "# Speaker notes — $(jq -r '.title' out/deck.json)"; echo
  jq -r '.slides[] | "## \(.heading)\n\n\(.speaker_notes)\n"' out/deck.json
} > out/speaker-notes.md

echo "built: out/deck.json ($(jq '.slides|length' out/deck.json) slides), out/slides.md, out/speaker-notes.md"
