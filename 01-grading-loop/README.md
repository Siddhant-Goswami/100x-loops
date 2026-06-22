# Loop 01 — The Autonomous Grading Loop

> An LLM autonomously using tools in a loop, until a machine-checkable condition
> says the work is done — applied to grading student submissions.
>
> Goal: **auto-clear the clearly-good and clearly-bad, and surface only the
> genuinely uncertain cases to the instructor.**

This is the first buildable loop from the dossier. Everything here runs **offline
and deterministically** out of the box (a mock grader stands in for the LLM), so
you can watch the loop's machinery before spending a single token. Flip one env
var to run it for real.

---

## The loop, in one picture

```
for each submission:                       ← OUTER loop  (the batch / "Ralph" while-loop)
  repeat up to MAX_ITERS:                  ← INNER loop  (verify → retry)
      grade it          (grader subagent / skill)         ← TAKE ACTION
      verify the grade  (rules-based Stop-hook gate)       ← VERIFY WORK
      valid? break                                          ← TERMINATION CONDITION
  escalate or auto-clear (confidence gate)                  ← who needs a human?
  append to grades.jsonl                                    ← accumulate state
```

This is exactly the Claude Agent SDK loop — **gather context → take action →
verify work → repeat** — with the verification step made *rules-based* (jq +
schema) instead of vibes. Rules-based checks are deterministic, free, and far
more reliable than asking another model "is this grade good?".

---

## What each piece is, and which loop concept it embodies

| File | Loop concept | What it does |
|------|--------------|--------------|
| `rubric.md` | the **stopping criteria**, made explicit | 3-level (`pass`/`partial`/`fail`) rubric + the escalation rule. Coarse buckets on purpose — models calibrate 3 levels, not 1–100. |
| `schema/grade.schema.json` | the **verifiable contract** | The shape every grade must have. If output doesn't conform, the loop isn't done. |
| `.claude/skills/grade/SKILL.md` | **encoded loop workflow** (`/grade`) | The rubric-as-a-slash-command. Turns "grade this" into a repeatable procedure. |
| `.claude/agents/grader.md` | **worker** (orchestrator-worker) | Reads submission + rubric → writes a structured grade. |
| `.claude/agents/grade-verifier.md` | **evaluator** (evaluator-optimizer) | Read-only by construction — *physically cannot rewrite what it grades.* It reports; the grader corrects. |
| `scripts/verify-grade.sh` | **the loop primitive** (Stop hook) | Exit `2` = "not done, keep working" (feeds the reason back). Exit `0` = "valid, may stop". Honors `stop_hook_active` to never loop forever. |
| `.claude/settings.json` | **deterministic control layer** | Wires `verify-grade.sh` as a `Stop` hook — the gate runs every turn, no exceptions. |
| `scripts/escalate.sh` | **human-in-the-loop gate** | Below the confidence threshold (or flagged) → copy to `review-queue/`. |
| `scripts/grade-all.sh` | **the outer autonomous loop** | Batches all submissions; bounded inner retry; the **max-iteration guardrail**. |
| `scripts/mock-grader.sh` | a **deterministic test double** | Fixed grades for the samples so the whole pipeline is offline + checkable. |

The key teaching contrast: a line in `CLAUDE.md` ("always produce a valid grade")
is *advisory* — the model usually complies. The **Stop hook is deterministic** —
the grade is validated every turn and the agent **cannot stop** until it passes.
That difference is the whole game.

---

## Run it

```bash
cd 01-grading-loop

# Offline, deterministic — watch the machinery (default):
./scripts/grade-all.sh

# For real, using Claude Code headless to grade:
GRADER=claude ./scripts/grade-all.sh

# Tunables:
MAX_ITERS=5 THRESHOLD=0.8 GRADER=mock ./scripts/grade-all.sh
```

Outputs:
- `grades.jsonl` — one machine-readable record per submission (the full class).
- `review-queue/` — **only** the uncertain grades; this is what the instructor opens.

The sample run routes `alice` (clear pass) and `bob` (clear fail) to **auto**, and
escalates `carol` (borderline, low confidence) and `dave` (gaming the rubric) to
**human review** — demonstrating all four paths.

### Single submission, interactively
From inside `01-grading-loop`, start Claude Code and run:
```
/grade submissions/carol.md
```
The `/grade` skill grades it, calls the `grade-verifier` subagent to audit, and the
`Stop` hook refuses to let the turn end until `out/carol.grade.json` is valid.

---

## Verify the loop's own machinery (no LLM needed)

```bash
# valid grade passes the gate
./scripts/verify-grade.sh out/alice.grade.json            # exit 0

# the gate names every defect in a broken grade
echo '{"submission_id":"x","criteria":{},"overall":"pass","confidence":2,"needs_human_review":false,"reasoning":"x"}' > out/_b.json
./scripts/verify-grade.sh out/_b.json ; rm out/_b.json     # exit 1, lists problems

# Stop-hook mode: no grade yet -> exit 2 ("keep working")
echo '{"stop_hook_active":false}' | ./scripts/verify-grade.sh   # exit 2

# infinite-loop guard: already blocked once -> exit 0 ("allow stop")
echo '{"stop_hook_active":true}'  | ./scripts/verify-grade.sh   # exit 0
```

---

## Guardrails (non-negotiable, per the dossier)

- **Max iterations** — `MAX_ITERS` bounds the inner retry loop; a submission that
  can't be graded validly is *routed to a human*, never looped forever.
- **Infinite-loop guard** — the Stop hook checks `stop_hook_active` so a block can
  never re-trigger itself endlessly.
- **No irreversible actions** — grading only ever *writes grade files*; the
  instructor remains the final authority on every escalated case.
- **Confidence honesty** — the grader is told to lower confidence when hedging,
  so the escalation gate has real signal to act on.

---

## Where to take it next (later layers)
- **Self-consistency / jury:** run the grader N times and aggregate; or a
  panel across model families to reduce self-preference bias.
- **Calibration:** log instructor overrides from `review-queue/`, then few-shot
  the skill with them so next term's loop agrees with the instructor more often.
  That is the on-ramp to the self-improving meta-loop (kept for last, with a
  human always in the loop).
