# Loop 00 — The Hello-Loop (one screen, one idea)

> The smallest vivid proof that **exit code 2 means "keep working."**
> One function, one test, one Stop hook. This is the agent loop with nothing else
> in the way — start here before Loops 01–03.

## The whole idea on one screen

`sum.js` ships **broken** on purpose (`a - b` instead of `a + b`). The Stop hook
runs `npm test` every time Claude tries to end its turn:

```
tests pass  -> exit 0 -> Claude may stop.      DONE.
tests fail  -> exit 2 -> failure fed back, Claude KEEPS WORKING.
```

That is the entire transition from "human vibing in a chat window" to "agent":
**the human is no longer the one deciding _is it done?_ — the test is.** The model
owns the control flow; a machine-checked condition owns termination.

## Files
| File | Role in the loop |
|------|------------------|
| `sum.js` | The code under test — the thing the agent edits. Ships buggy. |
| `sum.test.js` | The **termination condition**, written as a test (node's built-in runner, no deps). |
| `scripts/verify-tests.sh` | The **loop primitive**: `npm test` → exit 0 (done) or exit 2 (keep going). Guards `stop_hook_active` so it can't loop forever. |
| `.claude/settings.json` | Wires the script as a `Stop` hook — runs every turn, no exceptions. |

## Try it

**See the gate directly (no LLM, no install):**
```bash
cd 00-hello-loop
npm test                                          # fails — sum is broken
echo '{"stop_hook_active":false}' | ./scripts/verify-tests.sh ; echo $?   # prints feedback, exit 2
# fix it: change `a - b` to `a + b` in sum.js
echo '{"stop_hook_active":false}' | ./scripts/verify-tests.sh ; echo $?   # exit 0
```

**See the loop drive Claude:** open Claude Code in this directory and say:
> Make the tests pass.

Watch it try to finish, get blocked by the Stop hook ("Tests are still failing…"),
read the failure, fix `sum.js`, and only then be allowed to stop. You did not tell
it when it was done — the loop did.

## Why this is the right opener
Everything in Loops 01–03 is this same primitive with a richer verifier:
- **01 grading:** the test becomes "is the grade schema/rubric valid?"
- **02 research-deck:** the test becomes "every slide sourced, every topic covered?"
- **03 self-improving:** the loop edits its *own* rules between runs.

Same shape every time: **act → verify → exit 0 or exit 2 → repeat.**
