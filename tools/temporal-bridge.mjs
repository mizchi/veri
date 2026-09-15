import assert from "node:assert/strict";
import { runZ3, expectStatus } from "./solver.mjs";

// Finite, explicitly enumerated job model. This is not a symbolic MoonBit compiler.
export function validateJobModel(model) {
  assert.deepEqual(model.actions, ["Request", "Complete", "Wait", "Drop"]);
  assert.equal(model.predicates.pending.length, 4);
  assert.equal(model.predicates.done.length, 4);
  assert.equal(model.transitions.length, 4);
  assert.ok(Number.isInteger(model.initial) && model.initial >= 0 && model.initial < 4);
  const states = new Set();
  for (let i = 0; i < 4; i++) {
    assert.equal(typeof model.predicates.pending[i], "boolean");
    assert.equal(typeof model.predicates.done[i], "boolean");
    states.add(`${model.predicates.pending[i]},${model.predicates.done[i]}`);
    assert.equal(model.transitions[i].length, 4);
    for (const next of model.transitions[i]) assert.ok(Number.isInteger(next) && next >= -1 && next < 4);
  }
  assert.equal(states.size, 4, "All Boolean states must be represented");
  return model;
}

const and = xs => xs.length ? `(and ${xs.join(" ")})` : "true";
const or = xs => xs.length ? `(or ${xs.join(" ")})` : "false";
const indices = (start, stop) => Array.from({length: stop - start}, (_, i) => start + i);

export function lassoSource(model, depth, {fair, allowDrop}) {
  validateJobModel(model);
  assert.ok(Number.isInteger(depth) && depth >= 1 && depth <= 16);
  assert.equal(typeof fair, "boolean");
  assert.equal(typeof allowDrop, "boolean");
  const predicate = (flags, i) => or(flags.flatMap((set, state) => set ? [`(= s${i} ${state})`] : []));
  const enabled = model.transitions.map((row, state) => row[1] >= 0 && row[1] !== state);
  const lines = ["(set-logic QF_LIA)", "(declare-const loop Int)"];
  for (let i = 0; i <= depth; i++) lines.push(`(declare-const s${i} Int)`);
  for (let i = 0; i < depth; i++) lines.push(`(declare-const a${i} Int)`);
  lines.push(`(assert (= s0 ${model.initial}))`);
  for (let i = 0; i < depth; i++) {
    const choices = [];
    for (let state = 0; state < 4; state++) {
      for (let action = 0; action < 4; action++) {
        const next = model.transitions[state][action];
        if (next < 0 || (!allowDrop && action === 3)) continue;
        choices.push(and([`(= s${i} ${state})`, `(= a${i} ${action})`, `(= s${i + 1} ${next})`]));
      }
    }
    lines.push(`(assert ${or(choices)})`);
  }
  const loops = indices(0, depth).map(loop => {
    const cycle = indices(loop, depth);
    const violation = or(indices(0, depth).map(start => and([
      predicate(model.predicates.pending, start),
      ...indices(start, depth).map(i => `(not ${predicate(model.predicates.done, i)})`),
      ...cycle.map(i => `(not ${predicate(model.predicates.done, i)})`),
    ])));
    const fairness = fair ? or(cycle.flatMap(i => [
      `(not ${predicate(enabled, i)})`,
      and([`(= a${i} 1)`, `(not (= s${i} s${i + 1}))`]),
    ])) : "true";
    return and([`(= loop ${loop})`, `(= s${depth} s${loop})`, violation, fairness]);
  });
  lines.push(`(assert ${or(loops)})`);
  return lines.join("\n") + "\n";
}

export function findResponseCounterexample(model, bound, options, onQuery = () => {}) {
  assert.ok(Number.isInteger(bound) && bound >= 1 && bound <= 16);
  for (let depth = 1; depth <= bound; depth++) {
    const source = lassoSource(model, depth, options);
    onQuery(depth, source + "(check-sat)\n");
    const status = runZ3(source + "(check-sat)\n");
    if (status.trim() !== "sat") {
      expectStatus(status, "unsat"); // Unknown/errors must never become a passing bound.
      continue;
    }
    const names = ["loop", ...indices(0, depth + 1).map(i => `s${i}`), ...indices(0, depth).map(i => `a${i}`)];
    const witnessSource = source + `(check-sat)\n(get-value (${names.join(" ")}))\n`;
    const output = runZ3(witnessSource);
    expectStatus(output, "sat");
    onQuery(depth, witnessSource);
    const values = new Map([...output.matchAll(/\((loop|s\d+|a\d+) (\d+)\)/g)].map(m => [m[1], Number(m[2])]));
    assert.equal(values.size, names.length);
    assert.ok(names.every(name => values.has(name)));
    const witness = {
      states: indices(0, depth + 1).map(i => values.get(`s${i}`)),
      actions: indices(0, depth).map(i => values.get(`a${i}`)),
      loop: values.get("loop"),
    };
    return {result: "counterexample", bound: depth, witness};
  }
  return {result: "no-counterexample-up-to-bound", bound};
}
