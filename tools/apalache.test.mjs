import test from "node:test";
import assert from "node:assert/strict";
import {finiteTla, decodeFiniteTrace, temporalLoop, classifyApalache} from "./apalache.mjs";

const model = {
  initial: 0, actions: ["start", "finish", "tick"],
  transitions: [[1, -1, 0], [-1, 2, 1], [-1, -1, 2]],
  predicates: {safe: [true, true, true], pending: [false, true, false], done: [false, false, true]},
};
const response = {kind: "response", trigger: "pending", goal: "done"};
const int = n => ({"#bigint": String(n)});
function trace() {
  return {vars: ["s", "action", "__InLoop", "__saved_s", "__saved_action"], states:
    [[0, -1, false], [1, 0, false], [1, 2, false], [1, 2, true]].map(([s, a, loop]) =>
      ({s: int(s), action: int(a), __InLoop: loop, __saved_s: int(1), __saved_action: int(2)}))};
}

test("TLA export preserves self transitions and action-specific changing-step fairness", () => {
  const source = finiteTla(model, response, [1]);
  assert.match(source, /MODULE FiniteModel/);
  assert.match(source, /Init == s = 0 \/\\ action = -1/);
  assert.match(source, /\/\\ s' \\in 0\.\.2/);
  assert.match(source, /\/\\ action' \\in 0\.\.2/);
  assert.match(source, /Edge2 == \(s \\in \{0, 1, 2\} \/\\ s' = s\)/);
  assert.match(source, /Enabled1 == s \\in \{1\}/);
  assert.match(source, /Taken1 == action' = 1 \/\\ s' # s/);
  assert.match(source, /\[\]<>\(<<Taken1>>_vars\)/);
  assert.match(source, /Property == Fairness => \[\]\(Trigger => <>Goal\)/);
  assert.throws(() => finiteTla(model, {...response, trigger: "missing"}));
  assert.throws(() => finiteTla(model, response, [3]));
});

test("Apalache 0.62.2 temporal markers save the previous state; decoded lasso replays", () => {
  const itf = trace();
  assert.equal(temporalLoop(itf, ["s", "action"]), 2);
  assert.deepEqual(decodeFiniteTrace(itf, model, response), {states: [0, 1, 1, 1], actions: [0, 2, 2], loop: 2});
  assert.throws(() => decodeFiniteTrace(itf, model, response, [1]), /replay/);
});

test("traces reject missing loops, wrong saved states, labels and imprecise integers", () => {
  const mutations = [
    t => { t.states[3].__InLoop = false; },
    t => { t.states[0].__InLoop = true; },
    t => { t.states[2].__InLoop = true; t.states[3].__InLoop = false; },
    t => { t.states[3].__saved_s = int(2); },
    t => { t.states[3].s = int(2); },
    t => { t.states[2].action = int(1); },
    t => { t.states[0].action = int(0); },
    t => { t.states[1].s = {"#bigint": "9007199254740993"}; },
    t => { t.states[1].s = 1; },
    t => { t.states[1].s = {"#bigint": 1}; },
  ];
  for (const mutate of mutations) {
    const itf = trace(); mutate(itf);
    assert.throws(() => decodeFiniteTrace(itf, model, response));
  }
});

test("a changing multi-edge loop preserves its start and action fairness", () => {
  const graph = {initial: 0, actions: ["flip", "tick"], transitions: [[1, 0], [0, 1]],
    predicates: {pending: [true, false], done: [false, false]}};
  const itf = {vars: ["s", "action"], states: [[0, -1, false], [1, 0, false], [0, 0, true], [1, 0, true]]
    .map(([s, a, loop]) => ({s: int(s), action: int(a), __InLoop: loop, __saved_s: int(1), __saved_action: int(0)}))};
  assert.deepEqual(decodeFiniteTrace(itf, graph, response, [0]),
    {states: [0, 1, 0, 1], actions: [0, 0, 0], loop: 1});
});

test("finite safety and reachability traces do not require temporal instrumentation", () => {
  const itf = {vars: ["s", "action"], states: [
    {s: int(0), action: int(-1)}, {s: int(1), action: int(0)}, {s: int(2), action: int(1)},
  ]};
  assert.deepEqual(decodeFiniteTrace(itf, model, {kind: "reachability", predicate: "done"}),
    {states: [0, 1, 2], actions: [0, 1], loop: null});
  assert.throws(() => decodeFiniteTrace(itf, model, {kind: "safety", predicate: "safe"}));
});

test("only a completed bounded check or actual invariant violation is accepted", () => {
  const passed = "The outcome is: NoError\nChecker reports no error up to computation length 8\nEXITCODE: OK\n";
  const failed = "State 3: state invariant 0 violated.\nEXITCODE: ERROR (12)\n";
  assert.equal(classifyApalache(0, passed, 8), "no-counterexample-up-to-bound");
  assert.equal(classifyApalache(12, failed, 8), "counterexample");
  for (const [status, log] of [[0, ""], [0, passed.replace("length 8", "length 7")],
    [255, "Parsing error"], [12, "Solver timeout"], [null, passed], [0, failed]]) {
    assert.throws(() => classifyApalache(status, log, 8));
  }
});
