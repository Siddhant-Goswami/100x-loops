#!/usr/bin/env bash
# grade-all.sh — the autonomous grading loop, end to end.
#
# This is the OUTER loop (the "Ralph" while-loop applied to grading): iterate over
# every submission, and for each one run an INNER verify-and-retry loop until the
# grade is schema/rubric valid OR a max-iteration guard trips. Then the escalation
# gate decides auto-clear vs. human review. Results accumulate in grades.jsonl.
#
#   for each submission:                      <- outer loop (the batch)
#     repeat up to MAX_ITERS:                 <- inner loop (verify -> retry)
#       grade it
#       verify the grade (rules-based gate)
#       if valid: break
#     route via escalation gate
#
# Usage:
#   GRADER=mock   ./scripts/grade-all.sh      # offline, deterministic (default)
#   GRADER=claude ./scripts/grade-all.sh      # real grading via `claude -p /grade`
#
# Env:
#   GRADER     mock | claude         (default: mock)
#   MAX_ITERS  inner-loop cap        (default: 3)   <- the guardrail; never unbounded
#   THRESHOLD  escalation confidence (default: 0.75)

set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

GRADER="${GRADER:-mock}"
MAX_ITERS="${MAX_ITERS:-3}"
THRESHOLD="${THRESHOLD:-0.75}"

mkdir -p out review-queue
: > grades.jsonl              # fresh run
rm -f review-queue/*.grade.json 2>/dev/null || true

run_grader() {                # produce out/<id>.grade.json for a submission
  local sub="$1"
  if [ "$GRADER" = "claude" ]; then
    # Headless single-submission grade. The /grade skill writes out/<id>.grade.json
    # and its own Stop hook enforces validity before `claude` returns.
    claude -p "/grade $sub" \
      --allowedTools "Read,Write,Bash,Agent" \
      --output-format json >/dev/null
  else
    ./scripts/mock-grader.sh "$sub" >/dev/null
  fi
}

echo "== grading loop ==  grader=$GRADER  max_iters=$MAX_ITERS  threshold=$THRESHOLD"
auto=0; review=0; failed=0

for sub in submissions/*.md; do
  id="$(basename "$sub" .md)"
  grade="out/${id}.grade.json"
  ok=0

  # ---- inner verify/retry loop, bounded by MAX_ITERS (the guardrail) ----------
  for ((iter=1; iter<=MAX_ITERS; iter++)); do
    run_grader "$sub"
    if ./scripts/verify-grade.sh "$grade" >/dev/null 2>&1; then
      ok=1; break
    fi
    echo "  [$id] iter $iter: grade invalid, retrying..." >&2
  done

  if [ "$ok" -ne 1 ]; then
    echo "  [$id] FAILED after $MAX_ITERS iterations — routing to human." >&2
    mkdir -p review-queue
    [ -f "$grade" ] && cp "$grade" "review-queue/${id}.grade.json"
    failed=$((failed+1)); review=$((review+1))
    echo "{\"submission_id\":\"$id\",\"status\":\"unverified\",\"routed\":\"review\"}" >> grades.jsonl
    continue
  fi

  # ---- escalation gate: auto-clear or send to the instructor ------------------
  decision="$(./scripts/escalate.sh "$grade" "$THRESHOLD")"
  echo "  $decision"
  if echo "$decision" | grep -q '^REVIEW'; then
    review=$((review+1))
  else
    auto=$((auto+1))
  fi

  # ---- accumulate the machine-readable record --------------------------------
  jq -c --arg routed "$(echo "$decision" | grep -q '^REVIEW' && echo review || echo auto)" \
     '. + {routed:$routed}' "$grade" >> grades.jsonl
done

echo "== done ==  auto-cleared=$auto  human-review=$review  (unverified=$failed)"
echo "   machine log: grades.jsonl"
echo "   human queue: review-queue/  ($(ls review-queue/*.grade.json 2>/dev/null | wc -l | tr -d ' ') file(s))"
