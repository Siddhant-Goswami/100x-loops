#!/usr/bin/env bash
# verify-tests.sh — the entire agent loop, in one screen.
#
# Wired as a Stop hook, this runs every time Claude tries to end its turn:
#   - tests pass  -> exit 0 -> Claude is allowed to stop. DONE.
#   - tests fail  -> exit 2 -> the failure is fed back and Claude KEEPS WORKING.
# The `stop_hook_active` guard makes sure a block can't trigger itself forever.
#
# That is the whole idea: a machine-checked termination condition. The human is
# no longer the one deciding "is it done?" — the test is.

INPUT="$(cat 2>/dev/null || true)"

# Infinite-loop guard: if we already blocked once this turn, let it stop.
if [ "$(printf '%s' "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null)" = "true" ]; then
  exit 0
fi

cd "${CLAUDE_PROJECT_DIR:-$(dirname "$0")/..}" || exit 0

if npm test --silent >/dev/null 2>&1; then
  exit 0
else
  echo "Tests are still failing. Run 'npm test', read the failure, fix the code, and try again before finishing." >&2
  exit 2
fi
