import { mkdtempSync, writeFileSync, readFileSync, rmSync, mkdirSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";

// A capability probe, not a correctness theorem. Accepted lowering must still
// be reviewed for IEEE types, rounding, NaN, and signed-zero semantics.
const report = [];
for (const type of ["Float", "Double"]) {
  const directory = mkdtempSync(join(tmpdir(), "veri-fp-capability-"));
  try {
    writeFileSync(join(directory, "moon.mod"), 'name = "mizchi/fp-capability"\n');
    writeFileSync(join(directory, "moon.pkg"),
      (type === "Float" ? 'import { "moonbitlang/core/float" }\n' : '') + 'options("proof-enabled": true)\n');
    writeFileSync(join(directory, "probe.mbt"),
      "pub fn probe(x : " + type + ", y : " + type + ") -> " + type + " where {\n" +
      "  proof_ensure: _result => true,\n} { x + y }\n");
    const result = spawnSync("moon", ["prove"], {cwd: directory, encoding: "utf8", timeout: 30_000});
    if (result.error) throw result.error;
    const output = result.stdout + result.stderr;
    if (result.status !== 0 && output.includes("unsupported primitive operator in contracted function body")) {
      report.push({type, arithmeticLowering: "unsupported", ieeeCorrespondenceProved: false});
      console.log(type + ": native arithmetic lowering is unsupported; use the logical model and differential tests.");
    } else if (result.status === 0) {
      const proof = JSON.parse(readFileSync(join(directory, "_build/verif/fp-capability.proof.json"), "utf8"));
      if (proof.result !== "success") throw new Error("Missing successful capability proof: " + output);
      report.push({type, arithmeticLowering: "accepted", ieeeCorrespondenceProved: false});
      console.log(type + ": arithmetic lowering accepted; IEEE correspondence still needs a separate proof.");
    } else {
      throw new Error("Unexpected " + type + " capability failure:\n" + output);
    }
  } finally {
    rmSync(directory, {recursive: true, force: true});
  }
}
const output = new URL("../_build/", import.meta.url);
mkdirSync(output, {recursive: true});
writeFileSync(new URL("fp-capabilities.json", output), JSON.stringify(report, null, 2) + "\n");
