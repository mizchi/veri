import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { mkdirSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { validateJobModel, findResponseCounterexample } from "./temporal-bridge.mjs";

const root = fileURLToPath(new URL("../", import.meta.url));
const directory = new URL("../_build/temporal-bridge/", import.meta.url);
mkdirSync(directory, {recursive: true});
const runMoon = argument => JSON.parse(execFileSync("moon", [
  "-C", "examples", "run", "temporal/driver", "--target", "js", "--deny-warn", "--", argument,
], {cwd: root, encoding: "utf8", timeout: 60000, maxBuffer: 4 * 1024 * 1024}));
const model = validateJobModel(runMoon("export"));
writeFileSync(new URL("model.json", directory), JSON.stringify(model, null, 2) + "\n");
const cases = [
  {name: "unfair", fair: false, allowDrop: false, expected: "counterexample"},
  {name: "weak-fair", fair: true, allowDrop: false, expected: "no-counterexample-up-to-bound"},
  {name: "drop-weak-fair", fair: true, allowDrop: true, expected: "counterexample"},
];
const results = cases.map(check => {
  const found = findResponseCounterexample(model, 8, check, (depth, source) =>
    writeFileSync(new URL(`${check.name}-${depth}.smt2`, directory), source));
  assert.equal(found.result, check.expected, check.name);
  console.log(`${check.name}: ${found.result} (transitions=${found.bound})`);
  return {name: check.name, ...found};
});
const witnesses = results.flatMap(result => result.witness ? [result.witness] : []);
assert.equal(witnesses.length, 2);
const [unfair, dropped] = witnesses;
// The actual MoonBit evaluator must also reject forged transitions, fairness,
// graph variants, loop closures, and an execution which does complete.
const corrupted = [
  {...unfair, states: unfair.states.map((state, i) => i === 1 ? 3 : state)},
  {...unfair, actions: unfair.actions.map((action, i) => i === 0 ? -1 : action)},
  {...unfair, fair: true},
  {...dropped, allow_drop: false},
  {...unfair, loop_start: unfair.states.length},
  {...unfair, states: unfair.states.slice(0, -1)},
  {states: [0, 1, 2, 2], actions: [0, 1, 2], loop_start: 2, allow_drop: false, fair: true},
];
const replayed = runMoon(JSON.stringify([...witnesses, ...corrupted]));
assert.deepEqual(replayed, [...witnesses.map(() => true), ...corrupted.map(() => false)]);
console.log(`MoonBit replay: ${witnesses.length} counterexamples accepted; ${corrupted.length} invalid certificates rejected.`);
const toolchain = execFileSync("moon", ["version", "--all"], {encoding: "utf8"}).trim();
const solver = execFileSync("z3", ["-version"], {encoding: "utf8"}).trim();
writeFileSync(new URL("report.json", directory), JSON.stringify({
  toolchain, solver, modelSource: "examples/temporal/job.mbt", results,
  replayedCounterexamples: witnesses.length, rejectedCertificates: corrupted.length,
  note: "Local transition/finite-trace safety is proved separately by moon prove. Export, SMT encoding and lasso evaluation are tested, not formally proved.",
}, null, 2) + "\n");
