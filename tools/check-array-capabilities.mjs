import { mkdtempSync, writeFileSync, readFileSync, rmSync, mkdirSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";
import { configureWhy3 } from "./why3-config.mjs";

// These probes report frontend limitations, separately from rejected false laws.
const config = configureWhy3();
const probes = [
  {name: "array-calls", imports: ['"mizchi/veri/runtime/array" @runtime_array'], status: "accepted"},
  {name: "array-old", imports: [], status: "unsupported", diagnostic: "The value identifier old is unbound."},
  {name: "array-snapshot", imports: ['"mizchi/veri/arrays"', '"mizchi/veri/integer"', '"mizchi/veri/runtime/array" @runtime_array'], status: "compiler-error", diagnostic: "Assertion failed"},
  {name: "array-alias", imports: ['"mizchi/veri/runtime/array" @runtime_array'], status: "rejected-alias", diagnostic: "This application creates an illegal alias"},
];
const report = [];
for (const probe of probes) {
  const directory = mkdtempSync(join(tmpdir(), "veri-array-capability-"));
  try {
    const source = readFileSync(new URL(`../checks/capabilities/${probe.name}.mbt.txt`, import.meta.url), "utf8");
    writeFileSync(join(directory, "moon.mod"), 'name = "mizchi/array-capability"\nimport { "mizchi/veri@0.1.0" }\n');
    writeFileSync(join(directory, "moon.work"), 'members = [".", ' + JSON.stringify(fileURLToPath(new URL("../", import.meta.url))) + ']\n');
    writeFileSync(join(directory, "moon.pkg"), (probe.imports.length ? `import { ${probe.imports.join(", ")} }\n` : "") + 'options("proof-enabled": true)\n');
    writeFileSync(join(directory, "probe.mbt"), source);
    const checked = spawnSync("moon", ["check", "--deny-warn"], {cwd: directory, encoding: "utf8", timeout: 30_000});
    if (checked.error) throw checked.error;
    if (checked.status !== 0) {
      const diagnostics = checked.stdout + checked.stderr;
      if (probe.status === "accepted" || probe.name === "array-alias" || !diagnostics.includes(probe.diagnostic)) {
        throw new Error(`Unexpected ${probe.name} check failure:\n${diagnostics}`);
      }
      report.push({name: probe.name, source, status: probe.status, phase: "check", diagnostics});
      console.log(`${probe.name}: ${probe.status} (moon check)`);
      continue;
    }
    const proved = spawnSync("moon", ["prove", "--why3-config", config], {cwd: directory, encoding: "utf8", timeout: 30_000});
    if (proved.error) throw proved.error;
    const diagnostics = proved.stdout + proved.stderr;
    let status;
    if (proved.status === 0 && probe.name !== "array-alias") {
      const result = JSON.parse(readFileSync(join(directory, "_build/verif/array-capability.proof.json"), "utf8"));
      if (result.result !== "success" || result.summary.valid < 1) throw new Error("Missing positive capability proof");
      status = "accepted";
    } else if (proved.status !== 0 && probe.status !== "accepted" && diagnostics.includes(probe.diagnostic)) {
      status = probe.status;
    } else {
      throw new Error(`Unexpected ${probe.name} result:\n${diagnostics}`);
    }
    report.push({name: probe.name, source, status, phase: "prove", diagnostics});
    console.log(`${probe.name}: ${status}`);
  } finally {
    rmSync(directory, {recursive: true, force: true});
  }
}
const version = spawnSync("moon", ["version", "--all"], {encoding: "utf8"});
if (version.error) throw version.error;
if (version.status !== 0) throw new Error("Cannot record MoonBit version");
const output = new URL("../_build/", import.meta.url);
mkdirSync(output, {recursive: true});
writeFileSync(new URL("array-capabilities.json", output), JSON.stringify({toolchain: version.stdout.trim(), probes: report}, null, 2) + "\n");
