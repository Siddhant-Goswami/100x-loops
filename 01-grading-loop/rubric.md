# Grading Rubric — "Explain the agent loop"

**Assignment prompt given to students:**
> In 4–8 sentences, explain what makes an LLM *agent* different from a single
> LLM *call*. Your answer must mention (a) tools, (b) feedback/observation from
> the environment, and (c) a termination condition (how the loop decides it is done).

Grade every submission on the three criteria below. Use **three levels only**
— `pass` / `partial` / `fail`. Coarse buckets are deliberate: graders (human or
model) calibrate three levels reliably; fine-grained 1–100 scores are noisy and
non-reproducible.

---

## Criterion 1 — `correctness`
Does the answer get the core idea right: that an agent is an LLM **using tools in
a loop**, driven by environment feedback, until a stopping condition is met?

- **pass** — Identifies the loop as the defining difference; nothing stated is wrong.
- **partial** — Roughly right but vague, or one minor inaccuracy.
- **fail** — Misses the loop entirely, or contains a clear conceptual error
  (e.g. "an agent is just a bigger prompt").

## Criterion 2 — `completeness`
Does it cover all three required elements: (a) tools, (b) feedback/observation,
(c) a termination condition?

- **pass** — All three present and meaningful.
- **partial** — Two of three present.
- **fail** — One or zero present.

## Criterion 3 — `clarity`
Is it readable, well-structured, and within the 4–8 sentence bound?

- **pass** — Clear, coherent, within length.
- **partial** — Understandable but rambling, or slightly outside the length bound.
- **fail** — Confusing, or badly outside the length bound.

---

## Overall verdict mapping
- `pass` — correctness=pass AND completeness=pass AND clarity≠fail.
- `fail` — correctness=fail OR completeness=fail.
- `partial` — everything else.

## Escalation rule (when to ask a human)
Flag `needs_human_review: true` when **any** of these hold:
- grader `confidence` < **0.75**, or
- the three criteria disagree sharply (one `pass` and one `fail`), or
- the submission is empty, off-topic, or appears to be gaming the rubric.

The loop's job is not to replace the instructor — it is to **auto-clear the
clearly-good and clearly-bad, and surface only the genuinely uncertain.**
