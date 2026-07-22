#!/usr/bin/env bash
# demo.sh — the instructor walkthrough. Runs all four loops in sequence as one
# live demo, narrating what each one proves. Everything is offline and
# deterministic (test doubles stand in for the LLM), so it runs anywhere with
# bash + jq + node and never spends a token.
#
# Usage:
#   ./demo.sh            # run the whole series with pauses between loops
#   ./demo.sh --fast     # no pauses (CI / dry run)

set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; cd "$ROOT"

PAUSE=1; [ "${1:-}" = "--fast" ] && PAUSE=0
b() { printf '\n\033[1m%s\033[0m\n' "$*"; }            # bold
dim() { printf '\033[2m%s\033[0m\n' "$*"; }            # dim
beat() { [ "$PAUSE" = "1" ] && { printf '\n\033[2m(enter to continue)\033[0m'; read -r _; } || true; }

command -v jq   >/dev/null || { echo "need jq";   exit 1; }
command -v node >/dev/null || { echo "need node"; exit 1; }

b "============================================================"
b " Loop Engineering — four loops, one primitive"
b "============================================================"
dim "Every loop below is: act -> verify -> exit 0 (done) or exit 2 (keep going) -> repeat."
dim "The only thing that changes is the verifier."
beat

# ---------------------------------------------------------------- 00 -----------
b "── Loop 00 · hello-loop ─────────────────────────────────────"
dim "One function, one test, one Stop hook. The whole idea on one screen."
dim "sum.js ships BROKEN. The Stop hook runs npm test on every attempt to finish:"
( cd 00-hello-loop && rc=0; { echo '{"stop_hook_active":false}' | ./scripts/verify-tests.sh; } || rc=$?; \
  echo "  -> hook exit $rc : 2 means KEEP WORKING (the human didn't decide done — the test did)" )
beat

# ---------------------------------------------------------------- 01 -----------
b "── Loop 01 · autonomous grading ─────────────────────────────"
dim "Verifier becomes a rules-based schema/rubric gate. Auto-clear the clear cases,"
dim "escalate only the uncertain ones to the instructor."
( cd 01-grading-loop && GRADER=mock ./scripts/grade-all.sh )
beat

# ---------------------------------------------------------------- 02 -----------
b "── Loop 02 · research-to-artifact ───────────────────────────"
dim "Orchestrator-worker (parallel research) + evaluator-optimizer (QA-in-a-loop)."
dim "Verifier becomes: every slide has notes, every claim is sourced, every topic covered."
( cd 02-research-to-artifact && RESEARCHER=mock ./scripts/research-deck.sh )
beat

# ---------------------------------------------------------------- 03 -----------
b "── Loop 03 · self-improving meta-loop ───────────────────────"
dim "The loop edits its OWN rubric from instructor corrections — behind a human gate."
cd 03-self-improving
# The demo mutates rubric.md (that's the whole point of this loop), then restores
# it. Back up whatever the learner currently has — committed OR hand-edited — and
# put it back verbatim on the way out. (The old `git checkout -- rubric.md` reset
# to the committed version, silently discarding a learner's own edits, and only
# worked inside a git checkout at all.) An EXIT trap guarantees restore even on ^C.
_rubric_bak="$(mktemp)"; cp rubric.md "$_rubric_bak"
trap 'cp "$_rubric_bak" "$ROOT/03-self-improving/rubric.md" 2>/dev/null; rm -f "$_rubric_bak"' EXIT
rm -f calibration/decisions.jsonl calibration/agreement-history.jsonl calibration/proposed-calibration.md 2>/dev/null || true
./scripts/record-override.sh alice pass    pass    "" >/dev/null
./scripts/record-override.sh bob   fail    fail    "" >/dev/null
./scripts/record-override.sh carol partial pass    "implicit termination still satisfies criterion (c)" >/dev/null
./scripts/record-override.sh dave  fail    partial "keyword-stuffing is an integrity issue, not a content fail" >/dev/null
dim "Instructor adjudicated 4 cases (2 corrections). Agreement so far:"
./scripts/agreement.sh | sed 's/^/  /'
dim "learn.sh PROPOSES a rubric update — writes nothing until APPROVE=1:"
./scripts/learn.sh | sed -n '2,4p' | sed 's/^/  /'
dim "Instructor approves -> the rubric rewrites its own calibration block:"
APPROVE=1 ./scripts/learn.sh | sed -n '3p' | sed 's/^/  /'
sed -n '/BEGIN AUTO-CALIBRATION/,/END AUTO-CALIBRATION/p' rubric.md | sed -n '4,8p' | sed 's/^/    /'
# restore the learner's rubric.md verbatim and clear the trap
cp "$_rubric_bak" rubric.md && rm -f "$_rubric_bak"; trap - EXIT
rm -f calibration/decisions.jsonl calibration/agreement-history.jsonl calibration/proposed-calibration.md 2>/dev/null || true
cd "$ROOT"
beat

b "============================================================"
b " Done. Same primitive, four verifiers, increasing autonomy."
b "============================================================"
dim "00 a test · 01 a schema · 02 coverage rules · 03 the loop rewriting its own rules."
dim "Every one is bounded (max-iters), grounded (real checks), and human-gated where it matters."
