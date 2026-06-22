const test = require("node:test");
const assert = require("node:assert");
const { sum } = require("./sum");

// The verifier. This is the loop's termination condition, written as a test:
// the agent is "done" exactly when these pass — not when it says it is.
test("adds two positives", () => {
  assert.strictEqual(sum(2, 3), 5);
});

test("adds with zero", () => {
  assert.strictEqual(sum(0, 7), 7);
});

test("adds negatives", () => {
  assert.strictEqual(sum(-4, 1), -3);
});
