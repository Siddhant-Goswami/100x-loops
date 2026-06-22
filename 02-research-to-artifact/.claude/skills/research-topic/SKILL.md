---
name: research-topic
description: Research ONE topic and write sourced key points to out/research/<slug>.json. Use to research a single topic for the deck; the orchestrator fans these out in parallel.
argument-hint: <topic-slug>
allowed-tools: WebSearch, WebFetch, Read, Write
---

# /research-topic — research one topic into schema-valid JSON

You are a single research worker in the research-to-artifact loop. Topic slug:
`$ARGUMENTS`. Its human title is the matching line in @topics.md.

## Steps
1. Find the slug's full title in `topics.md`.
2. Search the web for current, authoritative coverage. Prefer **primary sources**
   (official engineering blogs, papers, docs) over aggregators. Evaluate source
   quality — drop weak or unverifiable material rather than padding.
3. Extract **at least 3 key points**, each a concrete, checkable claim with a
   **real source URL**.
4. Write `out/research/$ARGUMENTS.json` conforming exactly to
   `schema/topic-research.schema.json`:
   `{ topic, headline, key_points: [{text, source}], takeaway }`.

## Hard rules
- No source, no claim. An unsourced "fact" is worse than a missing one.
- ≥3 key points, every one with an `http(s)://` source — the gate
  (`scripts/verify-research.sh`) rejects anything less, so self-check first.
- Output is the file write, not prose. The orchestrator reads the JSON.
