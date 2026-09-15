import assert from "node:assert/strict";
import {execFileSync, spawnSync} from "node:child_process";
import {closeSync, mkdirSync, openSync, readFileSync, writeFileSync} from "node:fs";
import {join, relative} from "node:path";
import {fileURLToPath} from "node:url";
import {classifyApalache} from "./apalache.mjs";

const root = fileURLToPath(new URL("../", import.meta.url));
const binary = join(root, "_build/apalache-bin/bin/apalache-mc");

export function apalacheVersion() {
  const version = execFileSync(binary, ["version"], {encoding: "utf8", timeout: 30000}).trim();
  assert.equal(version, "0.62.2", "Revalidate ITF instrumentation and exit codes before upgrading Apalache");
  return version;
}

export function runApalache({runDirectory, name, source, options, bound = 8, next = "Next", checkDeadlocks = true}) {
  const dir = join(runDirectory, name);
  mkdirSync(dir);
  const config = join(dir, "config.json");
  writeFileSync(config, "{}\n");
  const args = ["check", `--config-file=${config}`, `--out-dir=${join(dir, "out")}`,
    `--run-dir=${join(dir, "artifacts")}`, `--length=${bound}`, "--init=Init", `--next=${next}`,
    "--smt-solver=z3", "--smt-encoding=oopsla19", "--algo=incremental", `--no-deadlock=${!checkDeadlocks}`,
    "--discard-disabled=false", "--tuning-options=search.invariant.mode=after", "--timeout-smt=120",
    ...options, source];
  console.log(`${name}: Apalache checking up to ${bound} transitions...`);
  const fd = openSync(join(dir, "output.log"), "w");
  let completed;
  try {
    completed = spawnSync(binary, args, {cwd: root, stdio: ["ignore", fd, fd], timeout: 300000});
  } finally { closeSync(fd); }
  assert.ifError(completed.error);
  assert.equal(completed.signal, null);
  const log = readFileSync(join(dir, "output.log"), "utf8");
  const result = classifyApalache(completed.status, log, bound);
  const trace = result === "counterexample"
    ? JSON.parse(readFileSync(join(dir, "artifacts/violation1.itf.json"), "utf8")) : undefined;
  return {result, trace, artifacts: relative(root, dir)};
}
