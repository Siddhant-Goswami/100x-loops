// The function under test. It ships BROKEN on purpose — this is the assignment.
//
// Ask Claude Code (in this directory) to "make the tests pass". The Stop hook
// runs `npm test` every time Claude tries to finish; while the test fails the
// hook exits 2 and feeds the failure back, so Claude CANNOT stop until sum()
// is correct. That single exit code is the whole agent loop in miniature.
//
// The one-character fix is `-`  ->  `+`. Try letting Claude find it.
function sum(a, b) {
  return a - b; // BUG: should be a + b
}

module.exports = { sum };
