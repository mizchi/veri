import test from "node:test";
import assert from "node:assert/strict";
import {createModelClient} from "./model-client.mjs";
import {evaluateWitness} from "./finite-temporal.mjs";

test("one client protocol exports all three MoonBit models", () => {
  for (const [driver, config, predicate] of [
    ["temporal/driver", {allow_drop: false}, "pending"],
    ["task_group/driver", {policy: 0, fault: 0}, "safe"],
    ["lease_clock/driver", {variant: 1, bound: 16}, "single_writer"],
  ]) {
    const client = createModelClient({driver});
    const model = client.load(config);
    assert.ok(model.predicates[predicate]);
    assert.deepEqual(client.replay([{states: [model.initial], actions: [], loop: null}], {
      config, property: {kind: "reachability", predicate},
    }), [model.predicates[predicate][model.initial]]);
  }
});

test("generic client checks a property and replays the solver witness in MoonBit", () => {
  const client = createModelClient({driver: "temporal/driver", defaults: {allow_drop: false}});
  const property = {kind: "response", trigger: "pending", goal: "done"};
  const found = client.check(property, {bound: 3});
  assert.equal(found.result, "counterexample");
  assert.deepEqual(client.replay([found.witness], {property, justice: [1]}), [false]);
  assert.equal(client.check(property, {bound: 3, justice: [1]}).result, "no-counterexample-up-to-bound");
});

test("client rejects malformed replies and never accepts a missing replay result", () => {
  const base = {driver: "unused", execute: () => JSON.stringify({version: 2, result: []})};
  assert.throws(() => createModelClient(base).replay([], {property: {kind: "safety", predicate: "p"}}), /version/i);
  const client = createModelClient({...base, execute: () => JSON.stringify({version: 1, result: []})});
  assert.throws(() => client.replay([{states: [0], actions: [], loop: null}], {
    property: {kind: "safety", predicate: "p"},
  }), /length/i);
  assert.throws(() => createModelClient({...base, execute: () => "not json"}).load());
});

test("client validates exported snapshot and justice metadata", () => {
  const model = {initial: 0, actions: ["tick"], transitions: [[0]], states: [0],
    predicates: {safe: [false]}, justice: []};
  for (const bad of [{...model, states: []}, {...model, justice: [1]}, {...model, justice: [0, 0]}]) {
    const client = createModelClient({driver: "unused", execute: () => JSON.stringify({version: 1, result: bad})});
    assert.throws(() => client.load());
  }
});

test("a solver result is rejected when the executable model refuses its witness", () => {
  const model = {initial: 0, actions: ["tick"], transitions: [[0]], states: [0],
    predicates: {safe: [false]}, justice: []};
  const client = createModelClient({driver: "unused", execute: (_command, args) => {
    const request = JSON.parse(args.at(-1));
    return JSON.stringify({version: 1, result: request.mode === "export" ? model : [false]});
  }});
  assert.throws(() => client.check({kind: "safety", predicate: "safe"}, {bound: 0}), /actual MoonBit model/);
});

test("generic MoonBit replay agrees with independent graph evaluation for every short Job trace", () => {
  const client = createModelClient({driver: "temporal/driver"});
  for (const allow_drop of [false, true]) {
    const config = {allow_drop}, model = client.load(config);
    const paths = [{states: [model.initial], actions: [], loop: null}];
    for (let i = 0; i < paths.length; i++) {
      const w = paths[i];
      if (w.actions.length === 4) continue;
      model.transitions[w.states.at(-1)].forEach((next, a) => {
        if (next >= 0) paths.push({states: [...w.states, next], actions: [...w.actions, a], loop: null});
      });
    }
    for (const property of [{kind: "safety", predicate: "safe"}, {kind: "reachability", predicate: "done"}]) {
      assert.deepEqual(client.replay(paths, {config, property}), paths.map(w => evaluateWitness(model, property, w)));
    }
    const lassos = paths.flatMap(w => Array.from({length: w.actions.length}, (_, loop) => ({...w, loop})));
    const property = {kind: "response", trigger: "pending", goal: "done"};
    for (const justice of [[], [1], [2]]) {
      assert.deepEqual(client.replay(lassos, {config, property, justice}),
        lassos.map(w => evaluateWitness(model, property, w, justice)));
    }
  }
});
