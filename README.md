# 100x — Loop Engineering in Agentic Engineering

[![loops-ci](https://github.com/Siddhant-Goswami/100x-loops/actions/workflows/ci.yml/badge.svg)](https://github.com/Siddhant-Goswami/100x-loops/actions/workflows/ci.yml)

![A real Claude Code session in 00-hello-loop: the agent reports the failing test and tries to stop, the Stop hook exits 2 and blocks it — so it fixes its own bug, reruns the tests, and only then is allowed to finish.](assets/hello-loop-demo.gif)

> **↑ 25 seconds, the whole thesis.** A real session in [`00-hello-loop`](./00-hello-loop):
> the agent reports the failing test and tries to stop — and the Stop hook **refuses**
> (`[block 1/3] Tests are still failing…`, exit code 2). Denied permission to stop, it goes
> back, fixes its own bug, reruns the tests, and only then is it *allowed* to finish. The
> test decided "done", not the model. Reproduce it yourself:
> `cd 00-hello-loop && claude "Make the tests pass."`

Buildable companion loops for the "derive before name" tutorial on the loop as
the defining primitive of agents. Each loop is a self-contained Claude Code
project you can run, read, and teach from.

> **The thesis:** the difference between an agent and a human vibing in a chat
> window is *who owns the loop*. In chat, **you** are the control structure. In an
> agent, the **machine** decides the next action, reads environment feedback
> itself, and decides when it's done. All the engineering lives in the
> **termination condition** and the **verification**.

## Quick start

```bash
./demo.sh          # runs all four loops in sequence, narrated (offline, deterministic)
./demo.sh --fast   # same, no pauses
```
Needs only `bash`, `jq`, and `node` — no API key, no `npm install`, no tokens spent.
Then open any loop's folder and read its `README.md`.

## The loops

Read them in order — each adds one layer to the same primitive.

| # | Loop | Status | What it demonstrates |
|---|------|--------|----------------------|
| 00 | [Hello-loop](./00-hello-loop) | ✅ built | The smallest vivid demo: one function, one test, one Stop hook. Exit code 2 = "keep working." Start here. |
| 01 | [Autonomous grading loop](./01-grading-loop) | ✅ built | Stop-hook block-and-feed-back verification, evaluator/critic subagent, confidence-gated human escalation, bounded external batch loop. |
| 02 | [Research-to-artifact loop](./02-research-to-artifact) | ✅ built | Orchestrator-worker + evaluator-optimizer: parallel research → slides + speaker notes → QA-in-a-loop. |
| 03 | [Self-improving meta-loop](./03-self-improving) | ✅ built | The loop edits its own rubric from instructor corrections — behind a human-approval gate. The advanced, last layer. |

Build order is deliberate: **hello-loop** (the bare primitive) → **grading**
(bounded, rules-checkable) → **research-to-artifact** (open-ended, multi-agent) →
**self-improving** (self-modifying, human-gated) last of all.

## Conventions across all loops
- **Verification is rules-based where possible** (tests / linters / schema), not
  LLM-as-judge — faster, deterministic, and per the dossier a 2–3× quality lever.
- **Every loop is bounded** — max-iterations, sandboxed side effects, and a human
  gate on anything irreversible. (Remember the DataTalks.Club `terraform destroy`.)
- **Each loop runs offline first** via a deterministic test double, so you can see
  the machinery before spending tokens.

Start with [`01-grading-loop`](./01-grading-loop).
