import test from "node:test";
import assert from "node:assert/strict";
import {loadLeaseClock, replayLeaseClock} from "./lease-clock-model.mjs";
import {leaseActions, referenceInitial, referenceStep, referenceStates, referenceWriters, stateKey} from "./lease-clock-reference.mjs";
import {evaluateWitness} from "./finite-temporal.mjs";

test("MoonBit export agrees with an independent oracle, including every frontier edge", () => {
  for (const [variant, bound] of [[0, 0], [0, 4], [0, 8], [1, 8], [1, 16]]) {
    const model = loadLeaseClock(variant, bound), repaired = variant === 1;
    const oracle = referenceStates(repaired, bound);
    const ids = new Map(model.states.map((s, i) => [stateKey(s), i]));
    assert.equal(ids.size, oracle.size);
    assert.deepEqual(model.actions, leaseActions);
    assert.deepEqual(model.states[model.initial], referenceInitial());
    const frontier = [];
    model.states.forEach((s, i) => {
      assert.deepEqual(s, oracle.get(stateKey(s)).state);
      assert.equal(model.exploration.depths[i], oracle.get(stateKey(s)).depth);
      const writers = referenceWriters(s, repaired);
      assert.equal(model.predicates.single_writer[i], writers.filter(Boolean).length <= 1);
      assert.equal(model.predicates.b_writer[i], writers[1]);
      let omitted = false;
      model.transitions[i].forEach((target, a) => {
        const next = referenceStep(s, a, repaired);
        if (next === null) return assert.equal(target, -1);
        const id = ids.get(stateKey(next));
        assert.equal(target, id ?? -1);
        if (id === undefined) {
          assert.equal(model.exploration.depths[i], bound);
          omitted = true;
        }
      });
      if (omitted) frontier.push(i);
    });
    assert.deepEqual(model.exploration.frontier, frontier);
    assert.equal(model.exploration.complete, frontier.length === 0);
    if (variant === 1 && bound === 16) {
      assert.equal(model.states.length, 470);
      assert.ok(model.exploration.complete);
      assert.ok(model.predicates.single_writer.every(Boolean));
    }
    if (variant === 0) assert.equal(model.exploration.complete, false);
  }
});

test("the Quint witness replays; forged states, events, loops and properties are rejected", () => {
  const model = loadLeaseClock(0, 8);
  const ids = new Map(model.states.map((s, i) => [stateKey(s), i]));
  const actions = [0, 0, 6, 7], states = [model.initial];
  let state = referenceInitial();
  for (const a of actions) {
    state = referenceStep(state, a, false);
    states.push(ids.get(stateKey(state)));
  }
  const witness = {states, actions, loop: null};
  assert.ok(evaluateWitness(model, {kind: "safety", predicate: "single_writer"}, witness));
  assert.deepEqual(replayLeaseClock([witness], {variant: 0, bound: 8}), [true]);
  const corrupted = [
    {...witness, states: [99999, ...states.slice(1)]},
    {...witness, actions: [99, ...actions.slice(1)]},
    {...witness, states: [...states.slice(0, -1), 0]},
    {...witness, actions: actions.slice(1)},
    {...witness, loop: 0},
  ];
  assert.deepEqual(replayLeaseClock(corrupted, {variant: 0, bound: 8}), corrupted.map(() => false));
  assert.deepEqual(replayLeaseClock([witness], {variant: 1, bound: 16}), [false]);
  assert.deepEqual(replayLeaseClock([witness], {property: "unknown"}), [false]);
});

test("a resource-limited exploration fails instead of reporting safety", () => {
  assert.throws(() => loadLeaseClock(0, 16), error =>
    error.status !== 0 && String(error.stdout).includes("StateLimitExceeded"));
});
