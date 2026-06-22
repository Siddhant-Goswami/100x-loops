---
name: research-deck
description: Research a list of topics and produce a sourced slide deck with per-slide speaker notes. Use when asked to build a lecture/deck from current AI-industry topics. Encodes the whole orchestrator-worker + QA pipeline.
argument-hint: [deck title]
allowed-tools: Read, Write, Bash, Agent, WebSearch, WebFetch
---

# /research-deck — research → artifact, in one command

You are the **orchestrator** of a research-to-artifact loop. Turn `topics.md`
into a sourced deck (`out/deck.json`) plus rendered `out/slides.md` and
`out/speaker-notes.md`. Deck title: `$ARGUMENTS` (default "State of Agentic AI").

## Pipeline
1. Read `topics.md` — one research topic per line.
2. **Research (parallel workers).** For each topic, dispatch a `researcher`
   subagent (they run independently — this is the parallelization pattern). Each
   writes `out/research/<slug>.json` and must satisfy
   `schema/topic-research.schema.json`: ≥3 key points, **every point carrying a
   real source URL**, plus a headline and takeaway. Verify each with
   `scripts/verify-research.sh`; if a topic fails, re-run that worker (bounded).
3. **Assemble.** Build `out/deck.json` against `schema/deck.schema.json`: a title
   slide, one content slide per topic (claims = the topic's sourced key points,
   speaker notes from its headline + takeaway), and a summary slide. Then render
   `out/slides.md` and `out/speaker-notes.md`. `scripts/build-deck.sh` does this
   deterministically; use it, or do it yourself with editorial judgment.
4. **QA loop (evaluator-optimizer).** Run the `deck-qa` subagent (or
   `scripts/qa-deck.sh out/deck.json`). It enforces the rules: **every slide has
   speaker notes, every content slide has ≥1 claim, every claim cites a source,
   every topic is covered.** If it reports problems, fix the deck and re-QA. Do
   not finish until QA passes — the Stop hook will block you otherwise.

## Rules
- An unsourced claim never reaches a slide. If research can't source it, drop it.
- Every slide gets speaker notes — no exceptions.
- More iterations cost more tokens (research is the expensive part). Don't loop
  for its own sake; stop as soon as QA passes.
