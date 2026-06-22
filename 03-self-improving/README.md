# Loop 03 — The Self-Improving Meta-Loop

> The loop that edits its **own rules** between runs. Each instructor correction
> becomes a new few-shot example baked into the rubric, so next term's grader has
> already seen where this term's grader was wrong.
>
> Kept for **last** on purpose: a self-modifying loop is only safe once the base
> loop is reliable and a human approves every change.

This is the outer loop wrapped around Loop 01: grade → instructor corrects →
**learn from the corrections** → grade better next time. It runs fully offline and
deterministically (pure bash + jq, no LLM) so you can watch the mechanism.

---

## The meta-loop

```
(Loop 01 grades a batch)
  instructor reviews the escalated cases        ← human in the loop
  record-override.sh  logs each decision         ← agreement AND corrections
  learn.sh            proposes a rubric update    ← from the corrections
  human approves  (APPROVE=1)                     ← the gate; nothing self-applies
  rubric.md's calibration block is rewritten      ← the loop edits its own rules
  agreement.sh        tracks machine-vs-human over time
(next batch grades with the improved rubric — repeat)
```

The dossier's principle, operationalized: **each observed failure becomes a new
guardrail.** And its safety rule: **never let a self-modifying loop touch a real
resource without human approval.**

---

## Files
| File | Role |
|------|------|
| `rubric.md` | The base rubric + a **managed `AUTO-CALIBRATION` block** that `learn.sh` rewrites. |
| `scripts/record-override.sh` | Instructor logs one adjudicated case (agreement or correction). |
| `scripts/agreement.sh` | The metric the loop moves: machine-vs-instructor agreement + history. |
| `scripts/learn.sh` | **The meta-step.** Turns corrections into calibration precedent. Proposal by default; applies only under `APPROVE=1`. |
| `calibration/` | Generated data: `decisions.jsonl`, `agreement-history.jsonl`, `proposed-calibration.md`. |

---

## Run the whole arc (offline, ~30 seconds)

```bash
cd 03-self-improving

# 1) An instructor adjudicates a batch — two agreements, two corrections:
./scripts/record-override.sh alice pass    pass    ""
./scripts/record-override.sh bob   fail    fail    ""
./scripts/record-override.sh carol partial pass    "implicit termination still satisfies criterion (c); don't require the literal word"
./scripts/record-override.sh dave  fail    partial "keyword-stuffing is an integrity issue, not a content fail"

# 2) Where do we stand?
./scripts/agreement.sh                 # -> 2/4 = 50%, two open corrections

# 3) The meta-loop PROPOSES a rubric update — but writes nothing yet:
./scripts/learn.sh                     # -> proposal only; rubric.md unchanged

# 4) The instructor reviews calibration/proposed-calibration.md, then approves:
APPROVE=1 ./scripts/learn.sh           # -> rubric.md's calibration block rewritten

# 5) Confirm the rubric now carries the precedent:
sed -n '/BEGIN AUTO-CALIBRATION/,/END AUTO-CALIBRATION/p' rubric.md
```

Then simulate a later term where the calibrated grader gets the once-wrong cases
right, and watch agreement climb:

```bash
./scripts/record-override.sh erin  pass    pass    ""
./scripts/record-override.sh frank partial partial ""
./scripts/record-override.sh grace pass    pass    ""
APPROVE=1 ./scripts/learn.sh
./scripts/agreement.sh                 # -> 5/7 = 71%, history shows 50% -> 71%
```

---

## The safety properties (why this loop is last)

- **Bounded blast radius.** `learn.sh` only edits text *between the managed
  markers* in `rubric.md`. It cannot alter the verdict mapping, the escalation
  rule, or anything else — let alone any file outside this folder.
- **Human approval gate.** Default is a *proposal*. `rubric.md` changes only when
  an instructor re-runs with `APPROVE=1`. The loop never self-applies.
- **Idempotent.** Re-running the apply regenerates the block in place — it never
  duplicates or drifts.
- **Auditable.** Every applied change appends a snapshot to
  `agreement-history.jsonl`, so you can see whether calibration actually helped.

The same caution the dossier draws from the DataTalks.Club `terraform destroy`
incident: stand a self-modifying loop up only after the base loop is reliable, and
keep a human on every change that touches something you can't trivially undo.

---

## How to wire it to a real LLM grader
Replace step 1's manual `record-override.sh` calls with: run Loop 01's
`grade-all.sh`, have the instructor adjudicate `review-queue/`, and emit one
`record-override.sh` call per decision. Then point Loop 01's `/grade` skill at
*this* `rubric.md` — now the grader reads the accumulated calibration precedent on
every run, closing the loop.
