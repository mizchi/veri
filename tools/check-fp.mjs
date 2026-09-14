import { readFileSync } from "node:fs";
import { expectStatus, runZ3 } from "./solver.mjs";

const directory = new URL("../checks/fp/", import.meta.url);
const checks = JSON.parse(readFileSync(new URL("manifest.json", directory), "utf8"));
if (checks.length === 0) throw new Error("No FP checks configured");
for (const {file, expected} of checks) {
  const output = runZ3(readFileSync(new URL(file, directory), "utf8"));
  expectStatus(output, expected);
  console.log(file + ": " + expected);
  if (expected === "sat") console.log(output.trim());
}
