import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { expectStatus, runZ3 } from "./solver.mjs";
import { lassoSource, validateJobModel } from "./temporal-bridge.mjs";

const directory = new URL("../checks/temporal/", import.meta.url);
const check = file => runZ3(readFileSync(new URL(file, directory), "utf8"));

// Independent explicit-state oracle. Bit 0 is pending, bit 1 is done.
function successors(state, drop = false) {
  return state === 0 ? [0, 1] : state === 1 ? [1, 2, ...(drop ? [0] : [])] : [state];
}

function paths(depth, drop, prefix = [0]) {
  if (depth === 0) return [prefix];
  return successors(prefix.at(-1), drop).flatMap(state => paths(depth - 1, drop, [...prefix, state]));
}

// Evaluate response on the infinite lasso by following positions until a
// position repeats. This does not use the SMT suffix/loop conjunction encoding.
function violatesResponse(path, loop) {
  const last = path.length - 2;
  for (let start = 0; start <= last; start++) {
    if (!(path[start] & 1)) continue;
    let position = start;
    const seen = new Set();
    let completed = false;
    while (!seen.has(position)) {
      seen.add(position);
      if (path[position] & 2) { completed = true; break; }
      position = position === last ? loop : position + 1;
    }
    if (!completed) return true;
  }
  return false;
}

function weaklyFair(path, loop) {
  for (let i = loop; i < path.length - 1; i++) {
    // Complete is disabled, or actually occurs, at least once per loop.
    if (path[i] !== 1 || path[i + 1] === 2) return true;
  }
  return false;
}

test("temporal lasso queries agree with exhaustive state search and replay their witnesses", () => {
  for (const [file, drop, fair] of [
    ["response-unfair.smt2", false, false],
    ["response-weak-fair.smt2", false, true],
    ["response-dropped-weak-fair.smt2", true, true],
  ]) {
    const bound = 4;
    const exists = paths(bound, drop).some(path =>
      path.slice(0, -1).some((state, loop) => state === path.at(-1) &&
        violatesResponse(path, loop) && (!fair || weaklyFair(path, loop))));
    const output = check(file);
    expectStatus(output, exists ? "sat" : "unsat");
    if (!exists) continue;
    const bindings = new Map([...output.matchAll(/\((loop|p\d+|d\d+) (true|false|\d+)\)/g)]
      .map(match => [match[1], match[2]]));
    assert.equal(bindings.size, 2 * (bound + 1) + 1);
    const loop = Number(bindings.get("loop"));
    assert.ok(Number.isInteger(loop) && loop >= 0 && loop < bound);
    const path = Array.from({length: bound + 1}, (_, i) => {
      const p = bindings.get(`p${i}`), d = bindings.get(`d${i}`);
      assert.ok(["true", "false"].includes(p) && ["true", "false"].includes(d));
      return (p === "true" ? 1 : 0) + (d === "true" ? 2 : 0);
    });
    assert.equal(path[0], 0);
    for (let i = 0; i < bound; i++) assert.ok(successors(path[i], drop).includes(path[i + 1]));
    assert.equal(path.at(-1), path[loop]);
    assert.ok(violatesResponse(path, loop));
    if (fair) assert.ok(weaklyFair(path, loop));
  }
});

test("job safety has both inductive obligations, a broken transition, and reachable completion", () => {
  for (const state of [0, 1, 2]) {
    assert.ok(successors(state).every(next => next !== 3));
  }
  assert.ok(paths(2, false).some(path => path.at(-1) === 2));
  expectStatus(check("safety-initial.smt2"), "unsat");
  expectStatus(check("safety-step.smt2"), "unsat");
  expectStatus(check("safety-broken-step.smt2"), "sat");
  expectStatus(check("reachable-completion.smt2"), "sat");
});

const model = {
  initial: 0, actions: ["Request", "Complete", "Wait", "Drop"],
  predicates: {pending: [false, true, false, true], done: [false, false, true, true]},
  transitions: [[1, -1, 0, -1], [-1, 2, 1, 0], [-1, -1, 2, -1], [-1, -1, 3, -1]],
};

test("MoonBit bridge encoding agrees with exhaustive lasso search at every tested bound", () => {
  for (let depth = 1; depth <= 6; depth++) {
    for (const [drop, fair] of [[false, false], [false, true], [true, true]]) {
      const exists = paths(depth, drop).some(path => path.slice(0, -1).some((state, loop) =>
        state === path.at(-1) && violatesResponse(path, loop) && (!fair || weaklyFair(path, loop))));
      expectStatus(runZ3(lassoSource(model, depth, {allowDrop: drop, fair}) + "(check-sat)\n"), exists ? "sat" : "unsat");
    }
  }
});

test("finite model export rejects missing states and malformed transitions", () => {
  const missing = structuredClone(model);
  missing.predicates.pending[3] = false;
  assert.throws(() => validateJobModel(missing));
  const bad = structuredClone(model);
  bad.transitions[0][0] = 4;
  assert.throws(() => validateJobModel(bad));
  assert.throws(() => lassoSource(model, 0, {allowDrop: false, fair: false}));
});
