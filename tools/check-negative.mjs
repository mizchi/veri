import { copyFileSync, existsSync, mkdtempSync, readFileSync, readdirSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { homedir } from "node:os";
import { spawnSync } from "node:child_process";
import { configureWhy3 } from "./why3-config.mjs";
import { selectNegativeChecks } from "./negative-selection.mjs";

const fixtures = new URL("../checks/negative/", import.meta.url);
const checks = selectNegativeChecks(
  JSON.parse(readFileSync(new URL("manifest.json", fixtures), "utf8")),
  process.argv.slice(2),
);
if (checks.length === 0) throw new Error("No negative proof controls configured");
const config = configureWhy3();

// Each false claim is isolated; ordinary moon prove contains only positive proofs.
for (const check of checks) {
  const directory = mkdtempSync(join(tmpdir(), "veri-negative-"));
  try {
    const source = new URL("../" + check.package + "/", import.meta.url);
    // Copy just this package, not its child packages containing unrelated laws.
    for (const entry of readdirSync(source, {withFileTypes: true})) {
      if (entry.isFile()) copyFileSync(new URL(entry.name, source), join(directory, entry.name));
    }
    writeFileSync(join(directory, "moon.mod"), 'name = "mizchi/veri-negative"\nimport { "mizchi/veri@0.1.0" }\n');
    writeFileSync(join(directory, "moon.work"), 'members = [".", ' +
      JSON.stringify(fileURLToPath(new URL("../", import.meta.url))) + ']\n');
    const sourceName = check.fixture.endsWith('.mbt.txt') ? "negative.mbt" : "negative.mbtp";
    writeFileSync(join(directory, sourceName), readFileSync(new URL(check.fixture, fixtures)));
    const result = spawnSync("moon", ["prove", "--why3-config", config], {
      // Some packages discharge substantial positive proofs before the false control.
      cwd: directory, encoding: "utf8", timeout: check.timeoutMs ?? 60_000,
      env: {...process.env, ...(check.machine ? {
        MOON_PROVE_PRELUDE_OVERRIDE: join(homedir(), ".moon/lib/prelude_proof_machine_int"),
      } : {})},
    });
    if (result.error) throw result.error;
    const reportPath = join(directory, "_build/verif/veri-negative.proof.json");
    if (!existsSync(reportPath)) {
      throw new Error("No proof report for " + check.package + "/" + check.fixture +
        "\n" + result.stdout + result.stderr);
    }
    const report = JSON.parse(readFileSync(reportPath, "utf8"));
    if (result.status === 0 || report.result === "success" ||
        !report.failures.some(failure => JSON.stringify(failure).includes("negative_control"))) {
      throw new Error("False claim was not rejected as a proof obligation: " + check.claim +
        "\n" + result.stdout + result.stderr);
    }
    console.log("Negative control (" + check.package + "): " + check.claim + " was not proved.");
    console.log(result.stdout.trim());
  } finally {
    rmSync(directory, {recursive: true, force: true});
  }
}
