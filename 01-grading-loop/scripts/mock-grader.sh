#!/usr/bin/env bash
# mock-grader.sh — a deterministic stand-in for the real `claude -p /grade` step.
#
# WHY THIS EXISTS: the real grading step calls an LLM, which costs money, needs
# network, and is non-deterministic. To teach and TEST the loop's machinery (the
# verification gate, the escalation router, the batch orchestration, the
# max-iteration guard) you want a grader whose output you can predict. This mock
# produces fixed, hand-authored grades for the sample submissions so the entire
# pipeline runs offline and its routing decisions are checkable.
#
# Swap this for the real grader by setting GRADER=claude in grade-all.sh.
#
# Usage: mock-grader.sh <submission.md>   ->   writes out/<id>.grade.json

set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

sub="${1:?usage: mock-grader.sh <submission.md>}"
id="$(basename "$sub" .md)"
mkdir -p out
target="out/${id}.grade.json"

case "$id" in
  alice)  # clearly good -> auto-clear
    cat > "$target" <<'JSON'
{
  "submission_id": "alice",
  "criteria": {
    "correctness":  { "level": "pass", "evidence": "'the machine, not the human, owns the control flow' — names the loop as the defining difference" },
    "completeness": { "level": "pass", "evidence": "covers tools ('call tools'), feedback ('observes the result... ground truth'), and termination ('a verifier... says stop')" },
    "clarity":      { "level": "pass", "evidence": "coherent, well within 4-8 sentences" }
  },
  "overall": "pass",
  "confidence": 0.93,
  "needs_human_review": false,
  "reasoning": "Hits all three required elements with correct framing of the agent loop; clear and concise."
}
JSON
    ;;
  bob)    # clearly bad -> auto-clear (a confident fail is also low-burden)
    cat > "$target" <<'JSON'
{
  "submission_id": "bob",
  "criteria": {
    "correctness":  { "level": "fail", "evidence": "'an agent is basically a really good prompt' — conceptual error; misses the loop entirely" },
    "completeness": { "level": "fail", "evidence": "no mention of tools, environment feedback, or a termination condition" },
    "clarity":      { "level": "pass", "evidence": "short and readable, within length" }
  },
  "overall": "fail",
  "confidence": 0.9,
  "needs_human_review": false,
  "reasoning": "Equates an agent with a large prompt; none of the three required elements are present."
}
JSON
    ;;
  carol)  # borderline -> escalate via low confidence
    cat > "$target" <<'JSON'
{
  "submission_id": "carol",
  "criteria": {
    "correctness":  { "level": "pass", "evidence": "'keeps going in a loop until the task is finished' and 'looks at what happens after each step' — loop + feedback correct" },
    "completeness": { "level": "partial", "evidence": "tools ('calling an API') and feedback ('adjusts') present; termination only implied by 'until the task is finished'" },
    "clarity":      { "level": "pass", "evidence": "clear, 3 sentences — slightly under the 4-8 bound" }
  },
  "overall": "partial",
  "confidence": 0.62,
  "needs_human_review": true,
  "reasoning": "Right ideas but the termination condition is only implicit and it is under length; a borderline pass/partial the instructor should adjudicate."
}
JSON
    ;;
  dave)   # gaming the rubric -> escalate via explicit flag
    cat > "$target" <<'JSON'
{
  "submission_id": "dave",
  "criteria": {
    "correctness":  { "level": "fail", "evidence": "'I included all the keywords from the rubric' — keyword stuffing, no explanation of the concepts" },
    "completeness": { "level": "partial", "evidence": "lists the words tools/feedback/termination but does not use them in any meaningful claim" },
    "clarity":      { "level": "fail", "evidence": "not coherent prose; an attempt to game the rubric" }
  },
  "overall": "fail",
  "confidence": 0.55,
  "needs_human_review": true,
  "reasoning": "Appears to be gaming the rubric by stuffing keywords; flagged for a human to confirm academic-integrity handling."
}
JSON
    ;;
  *)      # unknown submission -> emit a placeholder the verifier will reject,
          # which lets you SEE the Stop-hook loop fire on bad output.
    cat > "$target" <<JSON
{
  "submission_id": "$id",
  "criteria": {},
  "overall": "partial",
  "confidence": 0.5,
  "needs_human_review": true,
  "reasoning": "mock-grader has no canned grade for this submission"
}
JSON
    ;;
esac

echo "$target"
