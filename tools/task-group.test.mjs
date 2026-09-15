import test from "node:test";
import assert from "node:assert/strict";
import {loadTaskGroup} from "./task-group-model.mjs";

// Independent imperative reference of the documented, bounded abstraction.
// Child codes: absent=0, active=1, completing=2, failing=3, cancelling=4, done=5.
function referenceStep(input, action, mask) {
  const s = {...input};
  const terminal = child => child === 0 || child === 5;
  const stop = failed => {
    s.phase = 1;
    if (s.body === 0) s.body = 1;
    if (s.first === 1) s.first = 4;
    if (s.second === 1) s.second = 4;
    s.failed ||= failed;
  };
  const settle = () => {
    const waits = Number(s.body !== 2) + Number(!(mask & 1) && !terminal(s.first)) + Number(!(mask & 2) && !terminal(s.second));
    if (s.phase === 0 && waits === 0) stop(false);
  };
  const child = action.endsWith("first") ? "first" : "second";
  const held = child + "_held";
  if (action.startsWith("spawn-")) {
    const active = s.body !== 2 || !terminal(s.first) || !terminal(s.second);
    if (s[child] !== 0 || !(s.phase === 0 || (s.phase === 1 && active))) return null;
    s[child] = s.phase === 0 ? 1 : 4;
    s[held] = true;
  } else if (action.startsWith("complete-") || ["fail-first", "fail-second"].includes(action)) {
    if (s[child] !== 1) return null;
    s[child] = action.startsWith("complete-") ? 2 : 3;
  } else if (["cancel-first", "cancel-second"].includes(action)) {
    if (s[child] === 0) return null;
    if (s[child] === 1) s[child] = 4;
  } else if (action.startsWith("cleanup-")) {
    if (![2, 3, 4].includes(s[child])) return null;
    const fatal = s[child] === 3 && !(mask & (child === "first" ? 4 : 8));
    s[child] = 5;
    s[held] = false;
    if (fatal) stop(true); else settle();
  } else if (action === "body-return" || action === "body-fail") {
    if (s.body !== 0) return null;
    s.body = 2;
    if (action === "body-fail") stop(true); else settle();
  } else if (action === "body-cancelled") {
    if (s.body !== 1) return null;
    s.body = 2;
  } else if (action === "cancel-group" || action === "return-immediately") {
    if (s.phase !== 0) return null;
    stop(false);
    if (action === "cancel-group") s.cancel_requested = true;
  } else if (action === "join") {
    if (s.phase !== 1 || s.body !== 2 || !terminal(s.first) || !terminal(s.second)) return null;
    s.phase = 2;
  } else if (action === "finish-defers" || action === "fail-defers") {
    if (s.phase !== 2) return null;
    s.phase = 3;
    s.failed ||= action === "fail-defers";
  } else assert.equal(action, "tick");
  return s;
}

test("every exported edge agrees with an independent TaskGroup reference for all 16 policies", () => {
  for (let mask = 0; mask < 16; mask++) {
    const model = loadTaskGroup(mask);
    assert.deepEqual(model.states[0], {phase: 0, body: 0, first: 0, second: 0, first_held: false, second_held: false, cancel_requested: false, failed: false});
    assert.equal(new Set(model.states.map(s => JSON.stringify(s))).size, model.states.length);
    const reached = new Set([model.initial]), pending = [model.initial];
    while (pending.length) {
      for (const to of model.transitions[pending.pop()]) if (to >= 0 && !reached.has(to)) { reached.add(to); pending.push(to); }
    }
    assert.equal(reached.size, model.states.length, "Export is the reachable closure");
    model.states.forEach((state, s) => {
      const terminal = c => c === 0 || c === 5;
      const noOrphans = state.phase < 2 || (state.body === 2 && terminal(state.first) && terminal(state.second));
      const resources = (!terminal(state.first) || !state.first_held) && (!terminal(state.second) || !state.second_held);
      assert.equal(model.predicates.no_orphans[s], noOrphans);
      assert.equal(model.predicates.resources[s], resources);
      assert.ok(noOrphans && resources && model.predicates.safe[s]);
      for (let a = 0; a < model.actions.length; a++) {
        const expected = referenceStep(state, model.actions[a], mask);
        const actual = model.transitions[s][a];
        assert.deepEqual(actual < 0 ? null : model.states[actual], expected, `policy=${mask} state=${s} event=${model.actions[a]}`);
      }
    });
    assert.ok(model.states.some(s => s.phase === 3 && s.first === 5 && s.second === 5 && !s.failed));
    assert.ok(model.states.some(s => s.phase === 3 && s.failed));
  }
});
