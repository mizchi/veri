import { spawn, execFileSync } from "node:child_process";
import { mkdirSync, readFileSync, writeFileSync, readdirSync } from "node:fs";
import { createHash } from "node:crypto";
import { cpus, platform, arch, release, homedir } from "node:os";
import { join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { parseArgs } from "node:util";
import { parseSummaries, analyzeResults, renderReport, checkLimit } from "./bench-results.mjs";

const root = fileURLToPath(new URL("../", import.meta.url));
const {values, positionals} = parseArgs({
  allowPositionals: true,
  options: {"max-ratio": {type: "string"}, "from-log": {type: "string"}, "output-dir": {type: "string"}},
});
const target = positionals[0] ?? "native";
if (positionals.length > 1 || !["native", "js", "wasm", "wasm-gc"].includes(target)) {
  throw new Error("Usage: node tools/bench-collections.mjs [native|js|wasm|wasm-gc] [--max-ratio NUMBER]");
}
const limit = values["max-ratio"] === undefined ? null : Number(values["max-ratio"]);
if (limit !== null && (!Number.isFinite(limit) || limit <= 0)) throw new Error("max-ratio must be finite and positive");

function sourceFingerprint(directory) {
  const hash = createHash("sha256");
  function visit(relative) {
    for (const entry of readdirSync(join(directory, relative), {withFileTypes: true}).sort((a, b) => a.name.localeCompare(b.name, "en"))) {
      if (entry.name.startsWith(".") || entry.name === "_build") continue;
      const name = join(relative, entry.name);
      if (entry.isDirectory()) visit(name);
      else if (/\.(mbt|mbtp|mbti)$/.test(name) || entry.name === "moon.pkg") {
        hash.update(name + "\0").update(readFileSync(join(directory, name))).update("\0");
      }
    }
  }
  visit("");
  return hash.digest("hex");
}

const command = ["bench", "benchmarks/collections", "--release", "--target", target, "--no-parallelize", "--output-json"];
const environment = {
  timestamp: new Date().toISOString(),
  target, cpu: cpus()[0]?.model ?? "unknown", platform: platform(), arch: arch(), os_release: release(),
  node: process.version,
  moon: execFileSync("moon", ["version", "--all"], {cwd: root, encoding: "utf8"}).trim(),
  commit: execFileSync("git", ["rev-parse", "HEAD"], {cwd: root, encoding: "utf8"}).trim(),
  dirty: execFileSync("git", ["status", "--porcelain"], {cwd: root, encoding: "utf8"}).trim().length > 0,
  core_sha256: sourceFingerprint(join(homedir(), ".moon/lib/core")),
  runtime_sha256: sourceFingerprint(join(root, "runtime")),
  workloads_sha256: sourceFingerprint(join(root, "benchmarks/collections")),
  command: ["moon", ...command],
  imported_log: values["from-log"] ?? null,
};
const directory = resolve(root, values["output-dir"] ?? "_build/benchmarks");
mkdirSync(directory, {recursive: true});
const basename = join(directory, "collections-" + target);
let output;
if (values["from-log"]) {
  // For locally recorded moon bench output; metadata is captured at import time.
  output = readFileSync(resolve(root, values["from-log"]), "utf8");
} else {
  console.log(`Running release collection benchmarks on ${target}, sequentially (two passes per implementation).`);
  let stdout = "", stderr = "";
  const child = spawn("moon", command, {cwd: root, stdio: ["ignore", "pipe", "pipe"]});
  child.stdout.on("data", chunk => { stdout += chunk; });
  child.stderr.on("data", chunk => { stderr += chunk; process.stderr.write(chunk); });
  const code = await new Promise((resolve, reject) => {
    child.once("error", reject);
    child.once("close", resolve);
  });
  writeFileSync(basename + ".log", stdout);
  writeFileSync(basename + ".stderr.log", stderr);
  if (code !== 0) throw new Error(`moon bench failed (${code}); see ${basename}.log`);
  output = stdout;
}
const summaries = parseSummaries(output);
const results = analyzeResults(summaries);
const report = {schema: 1, environment, limit, results, summaries};
writeFileSync(basename + ".json", JSON.stringify(report, null, 2) + "\n");
writeFileSync(basename + ".md", renderReport(report));
console.log(renderReport(report));
console.log(`Reports: ${basename}.{json,md}`);
if (limit !== null && results.some(row => checkLimit(row, limit) !== "within")) {
  process.exitCode = 2;
}
