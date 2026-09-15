import test from "node:test";
import assert from "node:assert/strict";
import {execFileSync} from "node:child_process";
import {mkdtempSync, writeFileSync, rmSync, chmodSync} from "node:fs";
import {tmpdir} from "node:os";
import {join} from "node:path";
import {fileURLToPath} from "node:url";
import {createModelClient} from "./model-client.mjs";
import {checkFinite, evaluateWitness} from "./finite-temporal.mjs";

const cwd = fileURLToPath(new URL("../", import.meta.url));
const run = args => JSON.parse(execFileSync("moonx", ["veri.mbtx", ...args], {
  cwd, encoding: "utf8", stdio: ["ignore", "pipe", "pipe"], timeout: 180000, maxBuffer: 16 * 1024 * 1024,
}));
const flags = p => p.kind === "response" ? ["--response", p.trigger, p.goal]
  : [p.kind === "safety" ? "--safety" : "--reachable", p.predicate];

test("moonx uses the MoonBit checker for all three models and agrees with the JS oracle", () => {
  const cases = [
    ["temporal", {allow_drop: false}, {kind: "safety", predicate: "safe"}, 3, false, "no-counterexample-up-to-bound"],
    ["temporal", {allow_drop: false}, {kind: "response", trigger: "pending", goal: "done"}, 3, false, "counterexample"],
    ["temporal", {allow_drop: false}, {kind: "response", trigger: "pending", goal: "done"}, 3, true, "no-counterexample-up-to-bound"],
    ["temporal", {allow_drop: true}, {kind: "response", trigger: "pending", goal: "done"}, 3, true, "counterexample"],
    ["lease_clock", {variant: 0, bound: 4}, {kind: "safety", predicate: "single_writer"}, 4, false, "counterexample"],
    ["lease_clock", {variant: 1, bound: 16}, {kind: "safety", predicate: "single_writer"}, 4, false, "no-counterexample-up-to-bound"],
    ["lease_clock", {variant: 1, bound: 16}, {kind: "reachability", predicate: "b_writer"}, 6, false, "witness"],
    ["task_group", {policy: 0, fault: 0}, {kind: "reachability", predicate: "normal_return"}, 3, false, "witness"],
    ["task_group", {policy: 0, fault: 0}, {kind: "response", trigger: "closing", goal: "returned"}, 3, false, "counterexample"],
    ["task_group", {policy: 0, fault: 0}, {kind: "response", trigger: "closing", goal: "returned"}, 3, true, "no-counterexample-up-to-bound"],
    ["task_group", {policy: 0, fault: 1}, {kind: "safety", predicate: "no_orphans"}, 4, false, "counterexample"],
    ["task_group", {policy: 0, fault: 2}, {kind: "safety", predicate: "resources"}, 4, false, "counterexample"],
  ];
  for (const [name, config, property, bound, fair, expected] of cases) {
    const driver = `${name}/driver`;
    const model = createModelClient({driver}).load(config);
    const justice = fair ? model.justice : [];
    const result = run(["check", driver, "--module", "examples", "--config", JSON.stringify(config),
      ...flags(property), "--bound", String(bound), ...(fair ? ["--fair"] : [])]);
    assert.equal(result.result, expected, name);
    const reference = checkFinite(model, property, {bound, justice});
    assert.equal(result.result, reference.result);
    assert.equal(result.bound, reference.bound);
    if (result.witness) {
      const {loop_start, ...w} = result.witness;
      assert.ok(evaluateWitness(model, property, {...w, loop: loop_start ?? null}, justice));
    }
  }
});

test("moonx exports and replays certificates, while invalid input and solver failure exit unsuccessfully", () => {
  const driver = "temporal/driver", config = {allow_drop: false};
  const base = [driver, "--module", "examples", "--config", JSON.stringify(config)];
  assert.deepEqual(run(["export", ...base]), createModelClient({driver}).load(config));
  const directory = mkdtempSync(join(tmpdir(), "veri-cli-"));
  try {
    const file = join(directory, "witnesses.json");
    writeFileSync(file, JSON.stringify([
      {states: [0, 1, 1], actions: [0, 2], loop_start: 1},
      {states: [0, 2, 2], actions: [0, 2], loop_start: 1},
    ]));
    assert.deepEqual(run(["replay", ...base, "--response", "pending", "done", "--witnesses", file]), [true, false]);
    assert.deepEqual(run(["replay", ...base, "--response", "pending", "done", "--fair", "--witnesses", file]), [false, false]);
    const unknownSolver = join(directory, "unknown-z3");
    writeFileSync(unknownSolver, "#!/bin/sh\nprintf 'unknown\\n'\n");
    chmodSync(unknownSolver, 0o755);
    for (const args of [
      ["check", ...base, "--safety", "safe", "--bound", "-1"],
      ["check", ...base, "--safety", "missing"],
      ["check", ...base, "--response", "pending", "done", "--fair", "--justice", "[]"],
      ["check", ...base, "--safety", "safe", "--z3", join(directory, "missing-z3")],
      ["check", ...base, "--safety", "safe", "--z3", unknownSolver],
      ["check", "lease_clock/driver", "--module", "examples", "--config", '{"variant":0,"bound":3}', "--safety", "single_writer", "--bound", "4"],
    ]) assert.throws(() => run(args), error => error.status !== 0);
  } finally {
    rmSync(directory, {recursive: true, force: true});
  }
});
