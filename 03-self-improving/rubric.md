# Grading Rubric — "Explain the agent loop" (self-improving edition)

Same base rubric as Loop 01: grade `correctness`, `completeness`, `clarity` at
`pass` / `partial` / `fail`; escalate uncertain cases to a human.

The difference is the block at the bottom. As instructors correct the machine,
`scripts/learn.sh` rewrites the **auto-calibration** section with few-shot
examples drawn from those corrections — so next term's grader has already seen
where last term's grader was wrong. The instructor approves every change before
it lands. That is the meta-loop: *each observed failure becomes a new guardrail.*

## Verdict mapping
- `pass` — correctness=pass AND completeness=pass AND clarity≠fail.
- `fail` — correctness=fail OR completeness=fail.
- `partial` — everything else.

## Escalation rule
Flag for human review when grader `confidence` < 0.75, the criteria disagree
sharply, or the submission is empty / off-topic / gaming the rubric.

---

<!-- BEGIN AUTO-CALIBRATION (managed by scripts/learn.sh — do not hand-edit) -->
_No calibration examples yet. Run the grading loop, let instructors correct it,
record the corrections, and run `scripts/learn.sh` to populate this section._
<!-- END AUTO-CALIBRATION -->
