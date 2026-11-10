import { execFileSync, spawnSync } from "node:child_process";
import { mkdirSync, writeFileSync } from "node:fs";
import { cpus, platform, arch, release } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { parseSummaries } from "./bench-results.mjs";
import { analyzeSmtlib, renderSmtlib } from "./bench-smtlib-results.mjs";

const root = fileURLToPath(new URL("../", import.meta.url));
const target = process.argv[2] ?? "native";
if (process.argv.length > 3 || !["native", "js", "wasm", "wasm-gc"].includes(target)) {
  throw new Error("Usage: node tools/bench-smtlib.mjs [native|js|wasm|wasm-gc]");
}
const command = ["bench", "-p", "benchmarks/smtlib", "--release", "--target", target, "--no-parallelize"];
console.log(`Running release SMT-LIB benchmarks on ${target} (two passes per implementation).`);
const run = spawnSync("moon", command, {cwd: root, encoding: "utf8", maxBuffer: 1 << 28});
const directory = join(root, "_build/benchmarks");
mkdirSync(directory, {recursive: true});
const basename = join(directory, "smtlib-" + target);
writeFileSync(basename + ".log", run.stdout ?? "");
if (run.status !== 0) {
  process.stderr.write(run.stderr ?? "");
  throw new Error(`moon bench failed (${run.status}); see ${basename}.log`);
}
const summaries = parseSummaries(run.stdout);
const environment = {
  timestamp: new Date().toISOString(),
  target, cpu: cpus()[0]?.model ?? "unknown", platform: platform(), arch: arch(), os_release: release(),
  node: process.version,
  moon: execFileSync("moon", ["version", "--all"], {cwd: root, encoding: "utf8"}).trim(),
  commit: execFileSync("git", ["rev-parse", "HEAD"], {cwd: root, encoding: "utf8"}).trim(),
  dirty: execFileSync("git", ["status", "--porcelain"], {cwd: root, encoding: "utf8"}).trim().length > 0,
  command: ["moon", ...command],
};
const report = {schema: 1, environment, results: analyzeSmtlib(summaries), summaries};
writeFileSync(basename + ".json", JSON.stringify(report, null, 2) + "\n");
writeFileSync(basename + ".md", renderSmtlib(report));
console.log(renderSmtlib(report));
console.log(`Reports: ${basename}.{log,json,md}`);
