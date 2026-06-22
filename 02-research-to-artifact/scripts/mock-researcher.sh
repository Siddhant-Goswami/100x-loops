#!/usr/bin/env bash
# mock-researcher.sh — deterministic stand-in for a real research worker.
#
# The real worker calls WebSearch/WebFetch (an LLM + network, non-deterministic,
# costs tokens). This mock returns fixed, schema-valid research for the sample
# topics so the WHOLE pipeline — parallel fan-out, assembly, the QA-in-a-loop —
# runs offline and its output is predictable and testable.
#
# Swap for the real worker by setting RESEARCHER=claude in research-deck.sh.
#
# Usage: mock-researcher.sh <topic-slug>  ->  writes out/research/<slug>.json

set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

slug="${1:?usage: mock-researcher.sh <topic-slug>}"
mkdir -p out/research
target="out/research/${slug}.json"

case "$slug" in
  agent-loops)
    cat > "$target" <<'JSON'
{
  "topic": "agent-loops",
  "headline": "An agent is an LLM autonomously using tools in a loop until a stopping condition is met.",
  "key_points": [
    { "text": "Anthropic's working definition of an agent is 'LLMs autonomously using tools in a loop'.", "source": "https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents" },
    { "text": "The Claude Agent SDK frames the loop as 'gather context, take action, verify work, repeat'.", "source": "https://www.anthropic.com/engineering/building-agents-with-the-claude-agent-sdk" },
    { "text": "ReAct showed interleaving reasoning and acting beats prior methods by up to 34% absolute success rate.", "source": "https://arxiv.org/abs/2210.03629" }
  ],
  "takeaway": "What changes versus a single LLM call is that the machine, not the human, owns the control flow."
}
JSON
    ;;
  verification)
    cat > "$target" <<'JSON'
{
  "topic": "verification",
  "headline": "Giving an agent a way to verify its own work is the single biggest reliability lever.",
  "key_points": [
    { "text": "Claude Code's creator reports self-verification raises output quality roughly 2-3x.", "source": "https://www.anthropic.com/engineering/building-agents-with-the-claude-agent-sdk" },
    { "text": "Reflexion's verbal self-correction loop reached 91% pass@1 on HumanEval, beating GPT-4 at 80%.", "source": "https://arxiv.org/abs/2303.11366" },
    { "text": "Rules-based checks (tests, linters, schemas) are more reliable than LLM-as-judge for verifiable criteria.", "source": "https://www.anthropic.com/engineering/building-effective-agents" }
  ],
  "takeaway": "Prefer deterministic rules for the stopping condition wherever the criterion can be expressed as a check."
}
JSON
    ;;
  multi-agent-cost)
    cat > "$target" <<'JSON'
{
  "topic": "multi-agent-cost",
  "headline": "Multi-agent systems are more capable but dramatically more expensive, and errors compound.",
  "key_points": [
    { "text": "Anthropic's multi-agent research system outperformed single-agent Opus 4 by 90.2% on its internal eval.", "source": "https://www.anthropic.com/engineering/multi-agent-research-system" },
    { "text": "Multi-agent systems use about 15x more tokens than chat; single agents about 4x.", "source": "https://www.anthropic.com/engineering/multi-agent-research-system" },
    { "text": "Token usage alone explained about 80% of the performance variance on the BrowseComp eval.", "source": "https://www.anthropic.com/engineering/multi-agent-research-system" }
  ],
  "takeaway": "Much of the multi-agent gain is just spending more tokens, so reach for it only when the task warrants the cost."
}
JSON
    ;;
  *)
    # Unknown topic -> emit a deliberately INCOMPLETE research file (too few
    # key_points) so you can watch the verification gate reject it.
    cat > "$target" <<JSON
{
  "topic": "$slug",
  "headline": "Placeholder research for $slug (mock has no canned data).",
  "key_points": [
    { "text": "Only one point, which violates the >=3 rule on purpose.", "source": "https://example.com" }
  ],
  "takeaway": "This file should be rejected by verify, demonstrating the gate."
}
JSON
    ;;
esac

echo "$target"
