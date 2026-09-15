import test from "node:test";
import assert from "node:assert/strict";
import {checkFinite, evaluateWitness, querySource, validateFiniteModel} from "./finite-temporal.mjs";
import {finiteTla} from "./apalache.mjs";

const model = {
  initial: 0, actions: ["advance", "tick"], transitions: [[1, 0], [-1, 1]],
  predicates: {safe: [true, true], pending: [true, true], done: [false, false]},
  exploration: {complete: false, max_depth: 1, depths: [0, 1], frontier: [1]},
};
const safety = {kind: "safety", predicate: "safe"};
const response = {kind: "response", trigger: "pending", goal: "done"};

test("partial graphs cannot be checked beyond the explored depth or used for liveness", () => {
  assert.equal(checkFinite(model, safety, {bound: 1}).result, "no-counterexample-up-to-bound");
  assert.throws(() => querySource(model, safety, 2), /exploration/);
  assert.throws(() => checkFinite(model, safety, {bound: 2}), /exploration/);
  assert.throws(() => checkFinite(model, response, {bound: 1}), /liveness/);
  assert.throws(() => evaluateWitness(model, response,
    {states: [0, 1, 1], actions: [0, 1], loop: 1}), /liveness/);
  assert.throws(() => finiteTla(model, safety), /exploration/);
  assert.throws(() => finiteTla(model, safety, [], 2), /exploration/);
  assert.throws(() => finiteTla(model, response, [], 1), /liveness/);
  assert.match(finiteTla(model, safety, [], 1), /MODULE FiniteModel/);
});

test("complete finite graphs may be checked beyond their enumeration depth", () => {
  const complete = {...model, exploration: {...model.exploration, complete: true, frontier: []}};
  assert.equal(checkFinite(complete, response, {bound: 3}).result, "counterexample");
  assert.match(finiteTla(complete, response), /MODULE FiniteModel/);
  assert.throws(() => validateFiniteModel({...model, exploration: {...model.exploration, complete: true}}));
  assert.throws(() => validateFiniteModel({...model, exploration: {...model.exploration, frontier: [0]}}));
});
