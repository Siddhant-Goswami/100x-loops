# Loop 02 — The Research-to-Artifact Loop

> Orchestrator-worker + evaluator-optimizer: fan out parallel research across
> topics, assemble a sourced slide deck with per-slide speaker notes, then QA it
> in a loop until every rule passes.
>
> Goal: **turn a list of topics into a lecture-ready, fully-sourced deck — and
> refuse to ship one that has an unsourced claim or a slide without notes.**

Like Loop 01, this runs **offline and deterministically** out of the box (a mock
researcher stands in for the web-searching LLM). Flip one env var for real research.

---

## The loop, in one picture

```
read topics.md
PARALLEL:  research each topic   (workers fanned out with &)     ← parallelization
   verify each topic's research  (>=3 points, every point sourced) ← inner gate
assemble deck.json + slides.md + speaker-notes.md                 ← generation
QA loop:   qa-deck.sh            (rules-based evaluator)           ← evaluator-optimizer
   fail -> regenerate, retry (bounded by MAX_ITERS)
render final artifacts
```

Two loop patterns stacked: **orchestrator-worker** (one lead fans research out to
parallel workers and synthesizes) and **evaluator-optimizer** (a critic checks the
artifact and sends it back until it passes). The dossier's multi-agent research
system is exactly this shape.

---

## What each piece is, and which loop concept it embodies

| File | Loop concept | What it does |
|------|--------------|--------------|
| `topics.md` | the **work list** | One topic per line; drives the fan-out and the coverage check. |
| `schema/topic-research.schema.json` | **worker output contract** | ≥3 key points, **every point sourced**. No source ⇒ not a fact. |
| `schema/deck.schema.json` | **artifact contract** | Title + content + summary slides; every slide needs speaker notes. |
| `.claude/skills/research-deck/SKILL.md` | **encoded pipeline** (`/research-deck`) | The whole orchestrator in one slash command. |
| `.claude/agents/researcher.md` | **worker** | Researches ONE topic in its own context, in parallel. |
| `.claude/agents/deck-writer.md` | **synthesizer** | Assembles verified research into the deck. |
| `.claude/agents/deck-qa.md` | **evaluator** (read-only) | Audits the deck; *cannot edit it* — reports, doesn't patch. |
| `scripts/verify-research.sh` | **inner gate** | Rejects a topic's research if under-sourced. |
| `scripts/qa-deck.sh` | **the loop primitive** (Stop hook) | Exit `2` = "deck not done, keep working". Enforces: every slide has notes, every claim is sourced, every topic covered. |
| `.claude/settings.json` | **deterministic control** | Wires `qa-deck.sh` as a `Stop` hook. |
| `scripts/build-deck.sh` | **generation step** | Deterministically renders `deck.json` → `slides.md` + `speaker-notes.md`. |
| `scripts/research-deck.sh` | **the orchestrator** | Parallel fan-out + bounded retries + the QA loop. |
| `scripts/mock-researcher.sh` | **test double** | Fixed sourced research so the pipeline runs offline + checkable. |

---

## Run it

```bash
cd 02-research-to-artifact

# Offline, deterministic — watch the orchestration (default):
./scripts/research-deck.sh

# Real research via Claude Code headless + WebSearch:
RESEARCHER=claude ./scripts/research-deck.sh

# Tunables:
TITLE="State of Agentic AI" AUDIENCE="Cohort 7" MAX_ITERS=3 ./scripts/research-deck.sh
```

Outputs in `out/`:
- `deck.json` — the structured, QA'd deck (source of truth).
- `slides.md` — Marp-style rendered slides (`marp slides.md` → PDF/HTML).
- `speaker-notes.md` — per-topic notes for the lecturer.

Change the deck by editing `topics.md` — add a line, rerun, the loop adapts.

### Interactively
From inside `02-research-to-artifact`, start Claude Code and run `/research-deck`.
The skill dispatches a `researcher` per topic, a `deck-writer` to assemble, and the
`deck-qa` subagent to audit — and the `Stop` hook won't let the turn end until
`out/deck.json` passes QA.

---

## Verify the loop's own machinery (no LLM needed)

```bash
# a clean deck passes QA
./scripts/qa-deck.sh out/deck.json                                   # exit 0

# QA names every defect: blank notes + a non-URL source
jq '.slides[1].speaker_notes="" | .slides[2].claims[0].source="x"' out/deck.json > out/_b.json
./scripts/qa-deck.sh out/_b.json ; rm out/_b.json                    # exit 1, lists problems

# under-sourced research is rejected at the inner gate
./scripts/mock-researcher.sh unknown >/dev/null
./scripts/verify-research.sh out/research/unknown.json               # exit 1 (<3 points)

# Stop-hook: no deck yet -> exit 2 ; already blocked -> exit 0
echo '{"stop_hook_active":false}' | ./scripts/qa-deck.sh             # exit 2
echo '{"stop_hook_active":true}'  | ./scripts/qa-deck.sh             # exit 0
```

---

## Guardrails & the cost lesson

- **Bounded everywhere** — `MAX_ITERS` caps both research retries and the QA loop;
  a topic that can't be sourced aborts the run rather than looping forever.
- **Research is the expensive part.** This is the loop where the dossier's
  "token usage explains ~80% of the variance" lesson bites: more iterations and
  more parallel workers = better coverage = more tokens. Don't loop for its own
  sake — stop the moment QA passes.
- **Rules over judges.** "Every slide has notes / every claim has a source / every
  topic covered" are *checks*, not opinions — so they live in `qa-deck.sh`, not in
  an LLM. The `deck-qa` subagent adds only the judgment a rule can't express
  (does the source actually support the claim?).

---

## Where to take it next
- **Voting/jury** on contested facts: run two researchers per sensitive topic and
  keep only claims both surface.
- **Self-improving:** log QA rejections and feed recurring failure modes back into
  `SKILL.md` so next week's deck avoids them — the meta-loop, kept for last, with a
  human always approving before publish.
