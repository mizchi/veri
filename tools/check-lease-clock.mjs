import assert from "node:assert/strict";
import {mkdirSync, mkdtempSync, writeFileSync} from "node:fs";
import {join, relative} from "node:path";
import {fileURLToPath} from "node:url";
import {checkFinite} from "./finite-temporal.mjs";
import {finiteTla, decodeFiniteTrace} from "./apalache.mjs";
import {apalacheVersion, runApalache} from "./apalache-runner.mjs";
import {loadLeaseClock, replayLeaseClock} from "./lease-clock-model.mjs";

const args = process.argv.slice(2);
assert.ok(args.length === 0 || (args.length === 1 && args[0] === "--apalache"), "Usage: node tools/check-lease-clock.mjs [--apalache]");
const withApalache = args.length === 1;
const root = fileURLToPath(new URL("../", import.meta.url));
const directory = join(root, "_build/lease-clock");
mkdirSync(directory, {recursive: true});
const runDirectory = mkdtempSync(join(directory, "run-"));
const version = withApalache ? apalacheVersion() : undefined;
const results = [], models = new Map();
let exhaustive;
const save = status => writeFileSync(join(directory, withApalache ? "apalache-report.json" : "report.json"), JSON.stringify({
  status, checkedAt: new Date().toISOString(), apalache: version,
  source: "https://gist.github.com/mizchi/58550e8d335a532f15d8e0cd84f57231/3798163170230238b8242043898802e54e4a31c1",
  runDirectory: relative(root, runDirectory), exhaustive, results,
  scope: "Two-node, single-cell Quint model: TTL=3, clock offsets A=0/B=1, maximum time=6. Vulnerable exploration is depth-bounded; repaired exploration exhausts the finite closure. Safety and reachability only. All witnesses replay in the MoonBit model. No connection to celld or claim of an implementation/unbounded-clock proof.",
}, null, 2) + "\n");
save("running");
process.on("uncaughtExceptionMonitor", () => save("failed"));

for (const check of [
  {name: "vulnerable-short-prefix", variant: 0, exportDepth: 3, bound: 3, predicate: "single_writer", kind: "safety", expected: "no-counterexample-up-to-bound"},
  {name: "vulnerable-two-writers", variant: 0, exportDepth: 8, bound: 8, predicate: "single_writer", kind: "safety", expected: "counterexample", witnessDepth: 4},
  {name: "repaired-single-writer", variant: 1, exportDepth: 16, bound: 8, predicate: "single_writer", kind: "safety", expected: "no-counterexample-up-to-bound"},
  {name: "repaired-takeover-reachable", variant: 1, exportDepth: 16, bound: 8, predicate: "b_writer", kind: "reachability", expected: "witness", witnessDepth: 6},
]) {
  const key = `${check.variant}-${check.exportDepth}`;
  if (!models.has(key)) {
    const model = loadLeaseClock(check.variant, check.exportDepth);
    models.set(key, model);
    writeFileSync(join(runDirectory, `model-${key}.json`), JSON.stringify(model, null, 2) + "\n");
    if (check.variant === 1) {
      assert.equal(model.exploration.complete, true);
      assert.equal(model.states.length, 470);
      assert.ok(model.predicates.single_writer.every(Boolean));
      exhaustive = {result: "all-reachable-states-safe", states: model.states.length,
        maxDistance: Math.max(...model.exploration.depths), complete: true};
    } else assert.equal(model.exploration.complete, false);
  }
  const model = models.get(key);
  const property = {kind: check.kind, predicate: check.predicate};
  const sourceDir = join(runDirectory, `source-${check.name}`);
  mkdirSync(sourceDir);
  const source = join(sourceDir, "FiniteModel.tla");
  writeFileSync(source, finiteTla(model, property, [], check.bound));
  const z3 = checkFinite(model, property, {bound: check.bound,
    onQuery: (depth, text) => writeFileSync(join(sourceDir, `query-${depth}.smt2`), text)});
  assert.equal(z3.result, check.expected, check.name);
  if (check.witnessDepth !== undefined) assert.equal(z3.bound, check.witnessDepth);
  const replay = witness => assert.deepEqual(replayLeaseClock([witness], {
    variant: check.variant, bound: check.exportDepth, property: check.predicate,
  }), [true]);
  if (z3.witness) replay(z3.witness);
  let apalache;
  if (withApalache) {
    const found = runApalache({runDirectory, name: check.name, source, options: ["--inv=Property"], bound: check.bound,
      // A dead end or an omitted frontier successor is not a safety violation.
      // No stuttering edges are fabricated, and no liveness check is made.
      checkDeadlocks: false});
    const result = check.kind === "reachability"
      ? found.result === "counterexample" ? "witness" : "unreachable-up-to-bound" : found.result;
    assert.equal(result, z3.result, `${check.name}: Apalache/Z3 agreement`);
    const witness = found.trace ? decodeFiniteTrace(found.trace, model, property) : undefined;
    if (witness) replay(witness);
    apalache = {result, witness, artifacts: found.artifacts, events: witness?.actions.map(a => model.actions[a])};
  }
  results.push({...check, states: model.states.length, complete: model.exploration.complete,
    frontierStates: model.exploration.frontier.length, z3, apalache,
    events: z3.witness?.actions.map(a => model.actions[a])});
  save("running");
  console.log(`${check.name}: ${z3.result}${withApalache ? "; Apalache agrees" : ""}${z3.witness ? "; MoonBit replay accepted" : ""}.`);
}
save("complete");
console.log("Repaired finite model: all 470 reachable states are safe; maximum shortest-path distance is 14.");
