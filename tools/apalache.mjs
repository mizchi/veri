import assert from "node:assert/strict";
import {validateFiniteModel, validateCheckScope, evaluateWitness} from "./finite-temporal.mjs";

const set = values => `{${values.join(", ")}}`;
const members = flags => flags.flatMap((flag, i) => flag ? [i] : []);

// This exports an already enumerated graph, not arbitrary MoonBit source.
// action records the incoming edge, so identical endpoints retain their labels.
export function finiteTla(model, property, justice = [], bound) {
  validateFiniteModel(model);
  validateCheckScope(model, property, bound);
  assert.ok(["safety", "reachability", "response"].includes(property.kind));
  assert.equal(new Set(justice).size, justice.length);
  assert.ok(justice.every(a => Number.isInteger(a) && a >= 0 && a < model.actions.length));
  const predicate = name => {
    assert.ok(Object.hasOwn(model.predicates, name), `Missing predicate: ${name}`);
    return `s \\in ${set(members(model.predicates[name]))}`;
  };
  const lines = ["---------------- MODULE FiniteModel ----------------", "EXTENDS Integers",
    "VARIABLES", "  \\* @type: Int;", "  s,", "  \\* @type: Int;", "  action",
    "\\* @type: <<Int, Int>>;", "vars == <<s, action>>", `Init == s = ${model.initial} /\\ action = -1`];
  if (model.exploration && !model.exploration.complete) {
    lines.splice(1, 0, `\\* Partial graph: safety/reachability only, check length <= ${model.exploration.max_depth}.`);
  }
  model.actions.forEach((_, a) => {
    const groups = new Map();
    model.transitions.forEach((row, s) => {
      const dest = row[a];
      if (dest < 0) return;
      const key = dest === s ? "s" : String(dest);
      if (!groups.has(key)) groups.set(key, []);
      groups.get(key).push(s);
    });
    const choices = [...groups].map(([dest, sources]) => `(s \\in ${set(sources)} /\\ s' = ${dest})`);
    lines.push(`Edge${a} == ${choices.length ? choices.join("\n  \\/ ") : "FALSE"}`);
  });
  // Choose bounded variables once, then constrain the relation. This avoids
  // eagerly evaluating nested destination CASE expressions for every action.
  lines.push("Next ==", `  /\\ s' \\in 0..${model.transitions.length - 1}`,
    `  /\\ action' \\in 0..${model.actions.length - 1}`,
    `  /\\ (${model.actions.map((_, a) => `(action' = ${a} /\\ Edge${a})`).join("\n      \\/ ")})`);
  if (property.kind === "response") {
    lines.push(`Trigger == ${predicate(property.trigger)}`, `Goal == ${predicate(property.goal)}`);
    for (const a of justice) lines.push(
      `Enabled${a} == s \\in ${set(members(model.transitions.map((row, s) => row[a] >= 0 && row[a] !== s)))}`,
      `Taken${a} == action' = ${a} /\\ s' # s`,
      `Fair${a} == ([]<>(~Enabled${a})) \\/ ([]<>(<<Taken${a}>>_vars))`);
    lines.push(`Fairness == ${justice.length ? justice.map(a => `Fair${a}`).join(" /\\ ") : "TRUE"}`,
      "Property == Fairness => [](Trigger => <>Goal)");
  } else {
    lines.push(`Property == ${property.kind === "reachability" ? "~(" : "("}${predicate(property.predicate)})`);
  }
  return lines.join("\n") + "\n====================================================\n";
}

// Pinned to Apalache 0.62.2's temporal-to-safety instrumentation. The public
// ITF `loop` field is currently absent; __InLoop saves the preceding state.
export function temporalLoop(itf, variables) {
  const states = itf.states;
  assert.ok(Array.isArray(states) && states.length >= 2);
  assert.ok(states.every(s => typeof s.__InLoop === "boolean"));
  const first = states.findIndex(s => s.__InLoop);
  assert.ok(first > 0, "Missing or invalid temporal loop marker");
  assert.ok(states.slice(first).every(s => s.__InLoop), "Loop marker must stay set");
  const loop = first - 1;
  for (const v of variables) {
    assert.ok(Object.hasOwn(states[loop], v));
    assert.deepEqual(states.at(-1)[v], states[loop][v], `Loop does not close for ${v}`);
    for (const s of states.slice(first)) assert.deepEqual(s[`__saved_${v}`], states[loop][v], `Incorrect saved ${v}`);
  }
  return loop;
}

function integer(value) {
  assert.ok(value && typeof value === "object" && typeof value["#bigint"] === "string" && /^-?\d+$/.test(value["#bigint"]));
  const n = Number(value["#bigint"]);
  assert.ok(Number.isSafeInteger(n), "ITF integer exceeds exact JS range");
  return n;
}

export function decodeFiniteTrace(itf, model, property, justice = []) {
  assert.ok(Array.isArray(itf.vars) && ["s", "action"].every(v => itf.vars.includes(v)));
  assert.ok(Array.isArray(itf.states) && itf.states.length > 0);
  assert.equal(integer(itf.states[0].action), -1, "Invalid initial action sentinel");
  const witness = {
    states: itf.states.map(s => integer(s.s)),
    actions: itf.states.slice(1).map(s => integer(s.action)),
    loop: property.kind === "response" ? temporalLoop(itf, ["s", "action"]) : null,
  };
  assert.ok(evaluateWitness(model, property, witness, justice), "Apalache trace must replay independently");
  return witness;
}

export function classifyApalache(status, log, bound) {
  if (status === 0 && /The outcome is: NoError\b/.test(log) &&
      new RegExp(`Checker reports no error up to computation length ${bound}\\b`).test(log) &&
      /EXITCODE: OK\b/.test(log)) return "no-counterexample-up-to-bound";
  if (status === 12 && /state invariant \d+ violated\./.test(log) &&
      /EXITCODE: ERROR \(12\)/.test(log)) return "counterexample";
  throw new Error(`Apalache did not complete a supported check (exit=${status}):\n${log.slice(-3000)}`);
}
