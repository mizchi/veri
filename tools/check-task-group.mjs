import assert from "node:assert/strict";
import {mkdirSync, readFileSync, writeFileSync} from "node:fs";
import {execFileSync} from "node:child_process";
import {checkFinite} from "./finite-temporal.mjs";
import {loadTaskGroup, replayTaskGroup} from "./task-group-model.mjs";
import {taskGroupChecks} from "./task-group-cases.mjs";

const directory = new URL("../_build/task-group/", import.meta.url);
mkdirSync(directory, {recursive: true});
const models = new Map();
function checkedAsyncVersion() {
  const manifest = readFileSync(new URL("../.mooncakes/moonbitlang/async/moon.mod", import.meta.url), "utf8");
  const version = manifest.match(/^version\s*=\s*"([^"]+)"/m)?.[1];
  assert.equal(version, "0.21.3", "Recheck TaskGroup semantics before changing the async reference version");
  return version;
}
function getModel(policy, fault) {
  const key = `${policy}-${fault}`;
  if (!models.has(key)) {
    const model = loadTaskGroup(policy, fault);
    models.set(key, model);
    writeFileSync(new URL(`model-${key}.json`, directory), JSON.stringify(model, null, 2) + "\n");
  }
  return models.get(key);
}
const results = [];
for (const {policy = 0, fault = 0, fair = false, kind = "response", ...check} of taskGroupChecks) {
  const model = getModel(policy, fault);
  const property = kind === "response"
    ? {kind, trigger: check.property === "closing-response" ? "closing" : "body_done", goal: "returned"}
    : {kind, predicate: check.property};
  const found = checkFinite(model, property, {bound: 8, justice: fair ? model.justice : [],
    onQuery: (depth, source) => writeFileSync(new URL(`${check.name}-${depth}.smt2`, directory), source)});
  assert.equal(found.result, check.expected, check.name);
  if (found.witness) assert.deepEqual(replayTaskGroup([found.witness], {policy, fault, fair, property: check.property}), [true]);
  const events = found.witness?.actions.map(a => model.actions[a]);
  results.push({name: check.name, policy, fault, fair, property, ...found, events});
  console.log(`${check.name}: ${found.result} (transitions=${found.bound}, states=${model.states.length})`);
}
const unfair = results.find(r => r.name === "closing-unfair").witness;
const corrupted = [
  {...unfair, states: [99999, ...unfair.states.slice(1)]},
  {...unfair, actions: unfair.actions.map((a, i) => i === 0 ? 99999 : a)},
  {...unfair, loop: unfair.states.length},
  {...unfair, states: unfair.states.slice(1)},
];
assert.deepEqual(replayTaskGroup(corrupted, {property: "closing-response"}), corrupted.map(() => false));
assert.deepEqual(replayTaskGroup([unfair], {property: "closing-response", fair: true}), [false]);
const early = results.find(r => r.name === "broken-early-join").witness;
assert.deepEqual(replayTaskGroup([early], {property: "no_orphans", fault: 0}), [false]);
console.log("MoonBit replay: all witnesses accepted; 6 forged or mismatched certificates rejected.");
writeFileSync(new URL("report.json", directory), JSON.stringify({
  toolchain: execFileSync("moon", ["version", "--all"], {encoding: "utf8"}).trim(),
  solver: execFileSync("z3", ["-version"], {encoding: "utf8"}).trim(),
  asyncVersion: checkedAsyncVersion(), bound: 8, results, rejectedCertificates: 6,
  assumptions: "Weak fairness of child cleanup, body cancellation completion, joining and completion of group defers. No assumption that arbitrary child I/O completes.",
  boundary: "Two one-shot child slots plus the body. Pure transition safety is proved separately. Export, SMT encoding, lasso evaluation and the async adapter are tested, not proved. Injected faults describe broken models, not bugs in moonbitlang/async.",
}, null, 2) + "\n");
