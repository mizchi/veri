import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { execFileSync } from "node:child_process";

// Preserve Why3's standard transformations and arithmetic model. Only omit the
// two native-BV encoding fragments, retaining the upstream BV theory axioms.
// Never change the user's installed Why3 files or introduce new axioms.
export function arithmeticDriver(source, directory) {
  for (const name of ["smt-libv2-bv.gen", "z3_bv.gen"]) {
    const line = 'import "' + name + '"';
    if (source.split(line).length !== 2) throw new Error("Unexpected Why3 driver layout: " + name);
    source = source.replace(line, '(* Native BV encoding omitted for arithmetic correspondence proofs. *)');
  }
  return source.replace(/^import "([^"]+)"$/gm, (_, name) => 'import ' + JSON.stringify(join(directory, name)));
}

export function configureWhy3() {
  const moonDirectory = join(homedir(), ".moon");
  const dataDirectory = join(moonDirectory, "share/why3");
  const drivers = join(dataDirectory, "drivers");
  const output = fileURLToPath(new URL("../_build/why3/", import.meta.url));
  mkdirSync(output, {recursive: true});
  const driver = join(output, "z3-arithmetic.drv");
  writeFileSync(driver, arithmeticDriver(readFileSync(join(drivers, "z3_487.drv"), "utf8"), drivers));
  const version = execFileSync("z3", ["-version"], {encoding: "utf8"}).match(/^Z3 version (\d+\.\d+\.\d+)\b/)?.[1];
  if (!version) throw new Error("Unrecognized Z3 version");
  const config = join(output, "why3.conf");
  const strategy = [
    "start:",
    "c Z3," + version + " .2 1000",
    "c Z3-Arithmetic," + version + " .2 1000",
    "c Z3," + version + " 1 1000",
    "c Z3-Arithmetic," + version + " 1 1000",
    "t compute_specified start",
    "t split_vc start",
    "c Z3," + version + " 2 4000",
    "c Z3-Arithmetic," + version + " 2 4000",
    "",
  ].join("\n");
  writeFileSync(config, '[main]\nmagic = 14\ndatadir = ' + JSON.stringify(dataDirectory) +
    '\nlibdir = ' + JSON.stringify(join(moonDirectory, "lib/why3")) +
    '\nmemlimit = 1000\nrunning_provers_max = 16\ntimelimit = 5.0\n\n' +
    '[prover]\nname = "Z3"\nversion = "' + version + '"\ncommand = "z3 -smt2 -T:%t %f"\ndriver = "z3_487"\n\n' +
    '[prover]\nname = "Z3-Arithmetic"\nversion = "' + version + '"\ncommand = "z3 -smt2 -T:%t %f"\ndriver = ' + JSON.stringify(driver) + '\n\n' +
    '[strategy]\nname = "MoonBit_Auto"\ndesc = "Native bitvectors and arithmetic correspondence"\nshortcut = "4"\ncode = ' +
    '"' + strategy.replaceAll('"', '\\"') + '"\n');
  return config;
}
