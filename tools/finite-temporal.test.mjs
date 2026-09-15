import test from "node:test";
import assert from "node:assert/strict";
import { checkFinite, validateFiniteModel, evaluateWitness, querySource } from "./finite-temporal.mjs";
import {runZ3, expectStatus} from "./solver.mjs";

const model = {
  initial: 0, actions: ["start", "finish", "tick"],
  transitions: [[1, -1, 0], [-1, 2, 1], [-1, -1, 2]],
  predicates: { safe: [true, true, true], pending: [false, true, false], done: [false, false, true] },
};

test("finite response distinguishes unfair starvation from weak fairness", () => {
  const property = {kind: "response", trigger: "pending", goal: "done"};
  const unfair = checkFinite(model, property, {bound: 4});
  assert.equal(unfair.result, "counterexample");
  assert.ok(evaluateWitness(model, property, unfair.witness, []));
  assert.equal(evaluateWitness(model, property, unfair.witness, [1]), false);
  assert.equal(checkFinite(model, property, {bound: 4, justice: [1]}).result, "no-counterexample-up-to-bound");
});

test("finite safety and reachability check the initial and final states", () => {
  const bad = structuredClone(model);
  bad.predicates.safe[2] = false;
  const property = {kind: "safety", predicate: "safe"};
  const result = checkFinite(bad, property, {bound: 3});
  assert.equal(result.result, "counterexample");
  assert.equal(result.bound, 2);
  assert.ok(evaluateWitness(bad, property, result.witness, []));
  bad.predicates.safe[0] = false;
  assert.equal(checkFinite(bad, property, {bound: 0}).bound, 0);
  assert.equal(checkFinite(model, {kind: "reachability", predicate: "done"}, {bound: 2}).result, "witness");
});

test("lasso checks the whole repeated loop after a pending suffix", () => {
  const graph = {initial: 0, actions: ["next"], transitions: [[1], [2], [0]],
    predicates: {pending: [false, false, true], done: [false, true, false]}};
  const property = {kind: "response", trigger: "pending", goal: "done"};
  const witness = {states: [0, 1, 2, 0], actions: [0, 0, 0], loop: 0};
  assert.equal(evaluateWitness(graph, property, witness, []), false);
  assert.equal(checkFinite(graph, property, {bound: 4}).result, "no-counterexample-up-to-bound");
});

test("invalid graphs, forged transitions, nonclosing loops and invalid justice are rejected", () => {
  assert.throws(() => validateFiniteModel({...model, transitions: [[20, -1, 0]]}));
  assert.throws(() => checkFinite(model, {kind: "safety", predicate: "missing"}, {bound: 2}));
  assert.throws(() => checkFinite(model, {kind: "safety", predicate: "safe"}, {bound: 2, justice: [8]}));
  const property = {kind: "response", trigger: "pending", goal: "done"};
  for (const witness of [
    {states: [0, 1, 1], actions: [0, 1], loop: 1},
    {states: [0, 1, 2], actions: [0, 1], loop: 1},
    {states: [0, 1, 1], actions: [0, 2], loop: 3},
  ]) assert.equal(evaluateWitness(model, property, witness, []), false);
});

test("SMT response agrees with exhaustive lasso evaluation on varied small graphs", () => {
  let seed = 20260929;
  const random = n => { seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0; return seed % n; };
  for (let example = 0; example < 12; example++) {
    const graph = {initial: 0, actions: ["a", "b", "tick"],
      transitions: Array.from({length: 3}, (_, s) => [random(4) - 1, random(4) - 1, s]),
      predicates: {pending: Array.from({length: 3}, () => random(2) === 1),
        done: Array.from({length: 3}, () => random(3) === 0)}};
    const property = {kind: "response", trigger: "pending", goal: "done"};
    for (let depth = 1; depth <= 4; depth++) for (const justice of [[], [0], [0, 1]]) {
      function explore(states, actions) {
        if (actions.length === depth) {
          return states.slice(0, -1).some((s, loop) => s === states.at(-1) &&
            evaluateWitness(graph, property, {states, actions, loop}, justice));
        }
        return graph.transitions[states.at(-1)].some((next, action) => next >= 0 && explore([...states, next], [...actions, action]));
      }
      expectStatus(runZ3(querySource(graph, property, depth, justice) + "(check-sat)\n"), explore([0], []) ? "sat" : "unsat");
    }
  }
});
