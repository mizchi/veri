import { cpSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";

// Isolate a false theorem so normal moon prove always checks only true claims.
const directory = mkdtempSync(join(tmpdir(), "veri-negative-"));
try {
  cpSync(new URL("../libs/ieee754/", import.meta.url), directory, {recursive: true});
  writeFileSync(join(directory, "moon.mod"), 'name = "mizchi/veri-negative"\n');
  writeFileSync(join(directory, "negative.mbtp"),
    readFileSync(new URL("../checks/negative/nan-reflexive.mbtp.txt", import.meta.url)));
  const result = spawnSync("moon", ["prove"], {
    cwd: directory, encoding: "utf8", timeout: 45_000,
  });
  if (result.error) throw result.error;
  const report = JSON.parse(readFileSync(join(directory, "_build/verif/veri-negative.proof.json"), "utf8"));
  if (result.status === 0 || report.result === "success" ||
      !report.failures.some(failure => JSON.stringify(failure).includes("negative_control"))) {
    throw new Error("False NaN reflexivity was not rejected as a proof obligation:\n" + result.stdout + result.stderr);
  }
  console.log("Negative control: false NaN reflexivity was not proved.");
  console.log(result.stdout.trim());
} finally {
  rmSync(directory, {recursive: true, force: true});
}
