import { readFileSync, mkdirSync, writeFileSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { expectStatus, runZ3 } from "./solver.mjs";

// A small, fixed-model experiment, not a general LTL compiler. In particular,
// an UNSAT bounded lasso query is never reported as a temporal proof.
const directory = new URL("../checks/temporal/", import.meta.url);
const checks = JSON.parse(readFileSync(new URL("manifest.json", directory), "utf8"));
if (checks.length === 0) throw new Error("No temporal checks configured");
const reports = [];
for (const check of checks) {
  const output = runZ3(readFileSync(new URL(check.file, directory), "utf8"));
  expectStatus(output, check.expected);
  const result = check.expected === "sat" ? "witness-found"
    : check.kind === "lasso" ? "no-counterexample-at-bound" : "induction-obligation-proved";
  reports.push({ ...check, result, output });
  console.log(`${check.file}: ${result}${check.bound ? ` (transitions=${check.bound})` : ""}`);
  if (check.expected === "sat") console.log(output.trim());
}
mkdirSync(new URL("../_build/", import.meta.url), { recursive: true });
const toolchain = execFileSync("z3", ["-version"], { encoding: "utf8", timeout: 5000 }).trim();
writeFileSync(new URL("../_build/temporal-checks.json", import.meta.url), JSON.stringify({ toolchain, checks: reports }, null, 2) + "\n");
