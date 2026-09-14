import { accessSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { homedir } from "node:os";
import { join } from "node:path";

if (Number(process.versions.node.split(".")[0]) < 24) throw new Error("Node.js 24+ is required");
const why3 = join(homedir(), ".moon", "share", "why3");
for (const theory of ["ieee_float", "set", "bv", "map", "string", "seq", "list", "bag", "fmap", "bintree", "stack", "queue", "pqueue"]) {
  accessSync(join(why3, "stdlib", theory + ".mlw"));
}
console.log("Why3 data: " + why3);
console.log(execFileSync("moon", ["version", "--all"], {encoding: "utf8"}).trim());
console.log(execFileSync("z3", ["--version"], {encoding: "utf8"}).trim());
console.log("Node.js " + process.versions.node);
