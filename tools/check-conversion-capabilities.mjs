import { mkdtempSync, writeFileSync, readFileSync, rmSync, mkdirSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";

// Frontend support is distinct from value-preservation correctness.
const report = [];
for (const [source, target, expression] of [
  ["Int", "Int64", "x.to_int64()"],
  ["Int64", "Int", "x.to_int()"],
  ["UInt", "Int", "x.reinterpret_as_int()"],
  ["UInt64", "UInt", "x.to_uint()"],
  ["UInt16", "Int", "x.to_int()"],
  ["Byte", "Int", "x.to_int()"],
]) {
  const directory = mkdtempSync(join(tmpdir(), "veri-conversion-capability-"));
  try {
    writeFileSync(join(directory, "moon.mod"), 'name = "mizchi/conversion-capability"\n');
    writeFileSync(join(directory, "moon.pkg"), 'options("proof-enabled": true)\n');
    writeFileSync(join(directory, "probe.mbt"),
      `pub fn probe(x : ${source}) -> ${target} where {\n proof_ensure: _result => true,\n} { ${expression} }\n`);
    const result = spawnSync("moon", ["prove"], { cwd: directory, encoding: "utf8", timeout: 30_000 });
    if (result.error) throw result.error;
    const output = result.stdout + result.stderr;
    let lowering;
    if (result.status !== 0 && /unsupported primitive operator in contracted function body|unsupported type in verification/.test(output)) {
      lowering = "unsupported";
    } else if (result.status === 0) {
      const proof = JSON.parse(readFileSync(join(directory, "_build/verif/conversion-capability.proof.json"), "utf8"));
      if (proof.result !== "success") throw new Error("Missing successful capability proof: " + output);
      lowering = "accepted";
    } else {
      throw new Error(`Unexpected ${source} -> ${target} failure:\n${output}`);
    }
    report.push({ source, target, lowering, valuePreservationProved: false });
    console.log(`${source} -> ${target}: ${lowering}; native value preservation requires a separate proof.`);
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
}
const output = new URL("../_build/", import.meta.url);
mkdirSync(output, { recursive: true });
writeFileSync(new URL("conversion-capabilities.json", output), JSON.stringify(report, null, 2) + "\n");
