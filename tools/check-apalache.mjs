import assert from "node:assert/strict";
import {mkdirSync, mkdtempSync, readFileSync, writeFileSync} from "node:fs";
import {join, relative} from "node:path";
import {fileURLToPath} from "node:url";
import {decodeFiniteTrace, finiteTla, temporalLoop} from "./apalache.mjs";
import {apalacheVersion, runApalache} from "./apalache-runner.mjs";
import {checkFinite, evaluateWitness, validateFiniteModel} from "./finite-temporal.mjs";
import {loadTaskGroup, replayTaskGroup} from "./task-group-model.mjs";
import {taskGroupChecks} from "./task-group-cases.mjs";
import {loadJob, replayJob} from "./job-model.mjs";
import {validateJobModel} from "./temporal-bridge.mjs";

const root = fileURLToPath(new URL("../", import.meta.url));
const directory = join(root, "_build/apalache");
mkdirSync(directory, {recursive: true});
// Fresh directories prevent old traces from being accepted after a failed run.
const runDirectory = mkdtempSync(join(directory, "run-"));
const version = apalacheVersion();
const bound = 8;
const results = [];
const save = status => writeFileSync(join(directory, "report.json"), JSON.stringify({
  status, checkedAt: new Date().toISOString(), apalache: version, bound,
  runDirectory: relative(root, runDirectory), results,
  boundary: "Bounded checks of finite models, not unbounded liveness proofs or a proof of the async runtime. The incoming-action variable and Apalache's temporal instrumentation can increase the minimum counterexample length. Both backends use bound 8, but their bounds are not completeness-equivalent. All returned witnesses are independently evaluated and replayed in MoonBit.",
}, null, 2) + "\n");
save("running");
process.on("uncaughtExceptionMonitor", () => save("failed"));

const run = (name, source, options, next = "Next") =>
  runApalache({runDirectory, name, source, options, next, bound});

function compare(name, model, property, justice, apalache, expected, replay) {
  const z3 = checkFinite(model, property, {bound, justice,
    onQuery: (depth, source) => writeFileSync(join(root, apalache.artifacts, `z3-${depth}.smt2`), source)});
  const result = property.kind === "reachability"
    ? apalache.result === "counterexample" ? "witness" : "unreachable-up-to-bound"
    : apalache.result;
  assert.equal(result, expected, name);
  assert.equal(z3.result, result, `${name}: Z3 and Apalache disagree`);
  if (apalache.witness) {
    assert.ok(evaluateWitness(model, property, apalache.witness, justice));
    replay(apalache.witness);
  }
  if (z3.witness) replay(z3.witness);
  results.push({name, result, states: model.transitions.length, property, justice,
    apalacheTransitions: apalache.witness?.actions.length, witness: apalache.witness,
    events: apalache.witness?.actions.map(a => model.actions[a]),
    z3Transitions: z3.bound, artifacts: apalache.artifacts});
  save("running");
  console.log(`${name}: ${result}; Z3 agrees${apalache.witness ? "; both traces replay in MoonBit" : ""}.`);
}

const job = validateJobModel(loadJob(true));
writeFileSync(join(runDirectory, "job-model.json"), JSON.stringify(job, null, 2) + "\n");
for (const check of [
  {name: "job-safety", invariant: true, expected: "no-counterexample-up-to-bound"},
  {name: "job-unfair", expected: "counterexample"},
  {name: "job-fair", fair: true, expected: "no-counterexample-up-to-bound"},
  {name: "job-drop-fair", fair: true, drop: true, expected: "counterexample"},
]) {
  const model = validateFiniteModel({initial: job.initial, actions: job.actions,
    transitions: job.transitions.map(row => row.map((next, a) => a === 3 && !check.drop ? -1 : next)),
    predicates: {pending: job.predicates.pending, done: job.predicates.done, safe: job.predicates.pending.map((p, i) => !(p && job.predicates.done[i]))}});
  const property = check.invariant ? {kind: "safety", predicate: "safe"}
    : {kind: "response", trigger: "pending", goal: "done"};
  const justice = check.fair ? [1] : [];
  const found = run(check.name, join(root, "checks/temporal/Job.tla"), [
    check.invariant ? "--inv=Safe" : `--temporal=${check.fair ? "FairResponse" : "Response"}`,
  ], check.drop ? "DropNext" : "Next");
  if (found.trace) {
    const states = found.trace.states.map(s => {
      assert.equal(typeof s.pending, "boolean"); assert.equal(typeof s.done, "boolean");
      const id = job.predicates.pending.findIndex((p, i) => p === s.pending && job.predicates.done[i] === s.done);
      assert.ok(id >= 0); return id;
    });
    const actions = states.slice(1).map((next, i) => {
      const action = model.transitions[states[i]].indexOf(next);
      assert.ok(action >= 0); return action;
    });
    found.witness = {states, actions, loop: check.invariant ? null : temporalLoop(found.trace, ["pending", "done"])};
  }
  compare(check.name, model, property, justice, found, check.expected, w => {
    assert.deepEqual(replayJob([w], {property, fair: check.fair ?? false, allowDrop: check.drop ?? false}), [true]);
  });
}

const models = new Map();
for (const {policy = 0, fault = 0, fair = false, kind = "response", ...check} of taskGroupChecks) {
  const key = `${policy}-${fault}`;
  if (!models.has(key)) {
    const model = loadTaskGroup(policy, fault);
    models.set(key, model);
    writeFileSync(join(runDirectory, `task-group-${key}.json`), JSON.stringify(model, null, 2) + "\n");
  }
  const model = models.get(key);
  const property = kind === "response"
    ? {kind, trigger: check.property === "closing-response" ? "closing" : "body_done", goal: "returned"}
    : {kind, predicate: check.property};
  const justice = fair ? model.justice : [];
  const sourceDir = join(runDirectory, `source-${check.name}`);
  mkdirSync(sourceDir);
  const source = join(sourceDir, "FiniteModel.tla");
  writeFileSync(source, finiteTla(model, property, justice));
  const name = `task-group-${check.name}`;
  const found = run(name, source, [kind === "response" ? "--temporal=Property" : "--inv=Property"]);
  if (found.trace) found.witness = decodeFiniteTrace(found.trace, model, property, justice);
  compare(name, model, property, justice, found, check.expected,
    w => assert.deepEqual(replayTaskGroup([w], {policy, fault, fair, property: check.property}), [true]));
}
const asyncManifest = readFileSync(join(root, ".mooncakes/moonbitlang/async/moon.mod"), "utf8");
assert.match(asyncManifest, /^version\s*=\s*"0\.21\.3"/m, "Recheck TaskGroup semantics after an async upgrade");
save("complete");
console.log(`Apalache ${version}: ${results.length} checks agree with Z3. Report: _build/apalache/report.json`);
