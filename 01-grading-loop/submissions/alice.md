A single LLM call maps one prompt to one completion and then stops. An agent
wraps that call in a loop: the model can call tools (search, run code, read
files) to act on the world instead of only producing text. After each tool call
it observes the result — the "ground truth" feedback from the environment — and
uses that to decide what to do next. It keeps repeating this sense-decide-act-
observe cycle, accumulating context as it goes. The loop ends when a termination
condition is met: the model judges the goal achieved, or a verifier (tests, a
rubric, a max-iteration cap) says stop. So the defining difference is not a
bigger prompt — it is that the machine, not the human, owns the control flow.
