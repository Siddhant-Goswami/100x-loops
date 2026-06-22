---
name: grade
description: Grade a single student submission against the course rubric and emit a structured, schema-valid grade JSON. Use when asked to grade, score, or evaluate a submission file.
argument-hint: <path-to-submission.md>
allowed-tools: Read, Write, Bash, Agent
---

# /grade — grade one submission

You are running the **grading step of an autonomous grading loop**. Your job is to
turn one submission into one schema-valid grade. You are NOT the final authority —
uncertain cases get escalated to a human, so be honest about confidence.

## Inputs
- Submission file: `$ARGUMENTS`
- Rubric: @rubric.md
- Output schema: @schema/grade.schema.json

## Steps
1. Read the submission at `$ARGUMENTS` and read `rubric.md`.
2. Score each of the three criteria (`correctness`, `completeness`, `clarity`) at
   `pass` / `partial` / `fail`. For each, capture a short `evidence` string — a
   quote or specific pointer from the submission. No evidence ⇒ you cannot grade it.
3. Derive `overall` using the rubric's verdict mapping.
4. Set `confidence` (0–1) honestly. If you found yourself hedging, it is below 0.75.
5. Apply the rubric's **escalation rule** to set `needs_human_review`.
6. Write the grade to `out/<submission_id>.grade.json`, conforming exactly to
   `schema/grade.schema.json`. `submission_id` is the filename stem (e.g. `alice`).
7. Hand off to the verifier: use the `grade-verifier` subagent to re-check your
   grade against the rubric. If it reports a problem, fix the grade and re-write it.

## Hard rules
- Output **only** the file write — the JSON is the deliverable, not prose.
- Do not invent praise or criticism that has no evidence in the submission text.
- Keyword-stuffing the rubric is not a pass. Judge the *meaning*, and if a
  submission looks like it is gaming the rubric, set `needs_human_review: true`.
- The Stop hook will reject your turn if the grade file is missing or invalid —
  that is the loop forcing you to finish the job properly.
