import assert from "node:assert/strict";
import { runZ3, expectStatus } from "./solver.mjs";

const and = xs => xs.length ? `(and ${xs.join(" ")})` : "true";
const or = xs => xs.length ? `(or ${xs.join(" ")})` : "false";
const range = (a, b) => Array.from({length: b - a}, (_, i) => a + i);

export function validateFiniteModel(model) {
  const n = model.transitions.length, m = model.actions.length;
  assert.ok(n > 0 && n <= 4096 && m > 0 && m <= 64);
  assert.equal(new Set(model.actions).size, m);
  assert.ok(model.actions.every(a => typeof a === "string"));
  assert.ok(Number.isInteger(model.initial) && model.initial >= 0 && model.initial < n);
  if (model.states !== undefined) {
    assert.ok(Array.isArray(model.states));
    assert.equal(model.states.length, n, "Snapshot count must match the state domain");
  }
  if (model.justice !== undefined) {
    assert.ok(Array.isArray(model.justice));
    assert.equal(new Set(model.justice).size, model.justice.length);
    assert.ok(model.justice.every(a => Number.isInteger(a) && a >= 0 && a < m));
  }
  for (const row of model.transitions) {
    assert.equal(row.length, m);
    assert.ok(row.every(s => Number.isInteger(s) && s >= -1 && s < n));
  }
  for (const flags of Object.values(model.predicates)) {
    assert.equal(flags.length, n);
    assert.ok(flags.every(flag => typeof flag === "boolean"));
  }
  if (model.exploration !== undefined) {
    const scope = model.exploration;
    assert.equal(typeof scope.complete, "boolean");
    assert.ok(Number.isInteger(scope.max_depth) && scope.max_depth >= 0 && scope.max_depth <= 64);
    assert.equal(scope.depths.length, n);
    assert.equal(scope.depths[model.initial], 0);
    assert.ok(scope.depths.every(d => Number.isInteger(d) && d >= 0 && d <= scope.max_depth));
    assert.equal(new Set(scope.frontier).size, scope.frontier.length);
    assert.ok(scope.frontier.every(s => Number.isInteger(s) && s >= 0 && s < n && scope.depths[s] === scope.max_depth));
    assert.equal(scope.complete, scope.frontier.length === 0);
  }
  return model;
}

// A truncated successor table is sound only for prefixes inside its explored
// depth. Missing edges must never become evidence for a liveness result.
export function validateCheckScope(model, property, depth) {
  if (model.exploration && !model.exploration.complete) {
    assert.notEqual(property.kind, "response", "Incomplete exploration cannot be used for liveness");
    assert.ok(Number.isInteger(depth) && depth >= 0 && depth <= model.exploration.max_depth,
      "Check requires an explicit bound within the exploration depth");
  }
}

function validateProperty(model, property, justice) {
  assert.ok(["safety", "reachability", "response"].includes(property.kind));
  for (const name of property.kind === "response" ? [property.trigger, property.goal] : [property.predicate]) {
    assert.ok(Object.hasOwn(model.predicates, name), `Missing predicate: ${name}`);
  }
  assert.equal(new Set(justice).size, justice.length);
  assert.ok(justice.every(a => Number.isInteger(a) && a >= 0 && a < model.actions.length));
}

// Replay and temporal evaluation use ordinary graph traversal, independently
// of the SMT suffix/loop constraints. Fairness counts only changing steps.
export function evaluateWitness(model, property, witness, justice = []) {
  validateFiniteModel(model);
  validateProperty(model, property, justice);
  const {states, actions, loop} = witness;
  if (!Array.isArray(states) || !Array.isArray(actions) || states.length !== actions.length + 1 || states[0] !== model.initial) return false;
  validateCheckScope(model, property, actions.length);
  if (!states.every(s => Number.isInteger(s) && s >= 0 && s < model.transitions.length)) return false;
  for (let i = 0; i < actions.length; i++) {
    const a = actions[i];
    if (!Number.isInteger(a) || a < 0 || a >= model.actions.length || model.transitions[states[i]][a] !== states[i + 1]) return false;
  }
  if (property.kind !== "response") {
    if (loop !== null) return false;
    const flags = model.predicates[property.predicate];
    return property.kind === "safety" ? states.some(s => !flags[s]) : flags[states.at(-1)];
  }
  if (!Number.isInteger(loop) || loop < 0 || loop >= actions.length || states.at(-1) !== states[loop]) return false;
  for (const action of justice) {
    if (!range(loop, actions.length).some(i => {
      const next = model.transitions[states[i]][action];
      return next < 0 || next === states[i] || (actions[i] === action && states[i] !== states[i + 1]);
    })) return false;
  }
  for (let start = 0; start < actions.length; start++) {
    if (!model.predicates[property.trigger][states[start]]) continue;
    const seen = new Set();
    let i = start, reached = false;
    while (!seen.has(i)) {
      seen.add(i);
      if (model.predicates[property.goal][states[i]]) { reached = true; break; }
      i = i + 1 === actions.length ? loop : i + 1;
    }
    if (!reached) return true;
  }
  return false;
}

function modelSource(model) {
  const lines = ["(set-logic QF_UFLIA)", "(declare-fun next (Int Int) Int)"];
  model.transitions.forEach((row, s) => row.forEach((next, a) => lines.push(`(assert (= (next ${s} ${a}) ${next}))`)));
  const predicates = new Map();
  Object.entries(model.predicates).forEach(([name, flags], index) => {
    const symbol = `p${index}`;
    predicates.set(name, symbol);
    lines.push(`(define-fun ${symbol} ((s Int)) Bool ${or(flags.flatMap((set, s) => set ? [`(= s ${s})`] : []))})`);
  });
  return {source: lines.join("\n") + "\n", predicates};
}

export function querySource(model, property, depth, justice = [], compiled = modelSource(model)) {
  validateFiniteModel(model);
  validateProperty(model, property, justice);
  validateCheckScope(model, property, depth);
  assert.ok(Number.isInteger(depth) && depth >= 0 && depth <= 16);
  assert.ok(property.kind !== "response" || depth > 0);
  const {source, predicates} = compiled;
  const at = (name, i) => `(${predicates.get(name)} s${i})`;
  const lines = [];
  for (let i = 0; i <= depth; i++) {
    lines.push(`(declare-const s${i} Int)`, `(assert (and (<= 0 s${i}) (< s${i} ${model.transitions.length})))`);
  }
  lines.push(`(assert (= s0 ${model.initial}))`);
  for (let i = 0; i < depth; i++) {
    lines.push(`(declare-const a${i} Int)`, `(assert (and (<= 0 a${i}) (< a${i} ${model.actions.length})))`,
      `(assert (= s${i + 1} (next s${i} a${i})))`);
  }
  if (property.kind === "safety") {
    lines.push(`(assert ${or(range(0, depth + 1).map(i => `(not ${at(property.predicate, i)})`))})`);
  } else if (property.kind === "reachability") {
    lines.push(`(assert ${at(property.predicate, depth)})`);
  } else {
    lines.push("(declare-const loop Int)");
    const choices = range(0, depth).map(loop => {
      const cycle = range(loop, depth);
      const violation = or(range(0, depth).map(start => and([
        at(property.trigger, start),
        ...range(start, depth).map(i => `(not ${at(property.goal, i)})`),
        ...cycle.map(i => `(not ${at(property.goal, i)})`),
      ])));
      const fair = justice.map(a => or(cycle.flatMap(i => [
        `(< (next s${i} ${a}) 0)`, `(= (next s${i} ${a}) s${i})`,
        and([`(= a${i} ${a})`, `(not (= s${i} s${i + 1}))`]),
      ])));
      return and([`(= loop ${loop})`, `(= s${depth} s${loop})`, violation, ...fair]);
    });
    lines.push(`(assert ${or(choices)})`);
  }
  return source + lines.join("\n") + "\n";
}

export function checkFinite(model, property, {bound = 8, justice = [], onQuery = () => {}} = {}) {
  validateFiniteModel(model);
  validateProperty(model, property, justice);
  validateCheckScope(model, property, bound);
  assert.ok(Number.isInteger(bound) && bound >= (property.kind === "response" ? 1 : 0) && bound <= 16);
  const compiled = modelSource(model);
  for (let depth = property.kind === "response" ? 1 : 0; depth <= bound; depth++) {
    const source = querySource(model, property, depth, justice, compiled);
    onQuery(depth, source + "(check-sat)\n");
    const status = runZ3(source + "(check-sat)\n");
    if (status.trim() !== "sat") { expectStatus(status, "unsat"); continue; }
    const names = [...range(0, depth + 1).map(i => `s${i}`), ...range(0, depth).map(i => `a${i}`), ...(property.kind === "response" ? ["loop"] : [])];
    const witnessSource = source + `(check-sat)\n(get-value (${names.join(" ")}))\n`;
    const output = runZ3(witnessSource);
    expectStatus(output, "sat");
    onQuery(depth, witnessSource);
    const values = new Map([...output.matchAll(/\((s\d+|a\d+|loop) (\d+)\)/g)].map(m => [m[1], Number(m[2])]));
    assert.equal(values.size, names.length);
    assert.ok(names.every(name => values.has(name)));
    const witness = {states: range(0, depth + 1).map(i => values.get(`s${i}`)),
      actions: range(0, depth).map(i => values.get(`a${i}`)), loop: values.get("loop") ?? null};
    assert.ok(evaluateWitness(model, property, witness, justice), "Solver witness must replay independently");
    return {result: property.kind === "reachability" ? "witness" : "counterexample", bound: depth, witness};
  }
  return {result: property.kind === "reachability" ? "unreachable-up-to-bound" : "no-counterexample-up-to-bound", bound};
}
