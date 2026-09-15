import { mkdtempSync, writeFileSync, readFileSync, rmSync, mkdirSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";

// Probe direct calls, without assuming contracts for core. A trivial
// postcondition tests compiler support only, never behavioral correctness.
const probes = [
  ["map", "builtin", "Map[Int, Int]", "Int?", "xs.get(1)"],
  ["set", "set", "Set[Int]", "Bool", "xs.contains(1)"],
  ["list", "list", "List[Int]", "Int", "xs.length()"],
  ["queue", "queue", "Queue[Int]", "Int?", "xs.peek()"],
  ["immutable-pqueue", "immut/priority_queue", "PriorityQueue[Int]", "@core.PriorityQueue[Int]", "xs.push(1)"],
  ["sorted-set", "immut/sorted_set", "SortedSet[Int]", "Bool", "xs.contains(1)"],
];
const report = [];
for (const [name, pkg, type, outputType, expression] of probes) {
  const directory = mkdtempSync(join(tmpdir(), "veri-core-capability-"));
  const source = `pub fn probe(xs : @core.${type}) -> ${outputType} where {\n` +
    `  proof_ensure: _result => true,\n} { ${expression} }\n`;
  try {
    writeFileSync(join(directory, "moon.mod"), 'name = "mizchi/core-capability"\n');
    writeFileSync(join(directory, "moon.pkg"),
      `import { "moonbitlang/core/${pkg}" @core }\noptions("proof-enabled": true)\n`);
    writeFileSync(join(directory, "probe.mbt"), source);
    const check = spawnSync("moon", ["check", "--deny-warn"], {cwd: directory, encoding: "utf8", timeout: 30_000});
    if (check.error) throw check.error;
    if (check.status !== 0) throw new Error("Invalid core probe:\n" + check.stdout + check.stderr);
    const proof = spawnSync("moon", ["prove"], {cwd: directory, encoding: "utf8", timeout: 30_000});
    if (proof.error) throw proof.error;
    const diagnostics = proof.stdout + proof.stderr;
    let directCallLowering;
    if (proof.status !== 0 && diagnostics.includes("Error: [4207]") && diagnostics.includes(
      "only contracted functions, imported proof-callable functions, pure functions, and primitive operators can be called in contracted function bodies")) {
      directCallLowering = "unsupported";
    } else if (proof.status === 0) {
      const result = JSON.parse(readFileSync(join(directory, "_build/verif/core-capability.proof.json"), "utf8"));
      if (result.result !== "success") throw new Error("Missing successful capability report");
      directCallLowering = "accepted";
    } else {
      throw new Error(`Unexpected ${name} capability failure:\n${diagnostics}`);
    }
    report.push({name, package: `moonbitlang/core/${pkg}`, expression, source, directCallLowering,
      behavioralCorrespondenceProved: false, diagnostics});
    console.log(`${name} (${expression}): direct contracted call ${directCallLowering}; behavioral correspondence is not proved by this probe.`);
  } finally {
    rmSync(directory, {recursive: true, force: true});
  }
}
const output = new URL("../_build/", import.meta.url);
mkdirSync(output, {recursive: true});
const version = spawnSync("moon", ["version", "--all"], {encoding: "utf8"});
if (version.error) throw version.error;
if (version.status !== 0) throw new Error("Cannot record MoonBit version");
writeFileSync(new URL("core-capabilities.json", output),
  JSON.stringify({toolchain: version.stdout.trim(), probes: report}, null, 2) + "\n");
