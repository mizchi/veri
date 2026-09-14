import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { execFileSync } from "node:child_process";
import { installedCvc5 } from "./cvc5.mjs";

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

// Keep Why3's GenericFloat/Float32/Float64 axioms and rounding-error lemmas.
// The native FP fragment removes these properties in favor of SMT operations;
// this alternative uses Why3's abstract real-valued model instead.
export function realFloatDriver(source, directory) {
  const line = 'import "smt-libv2-floats.gen"';
  if (source.split(line).length !== 2) throw new Error("Unexpected Why3 driver layout: native floats");
  source = source.replace(line, '(* Use upstream real-valued float theories. *)');
  for (const width of [32, 64]) {
    const pattern = new RegExp('^theory ieee_float.Float' + width + '\\n[\\s\\S]*?^end\\s*$', 'gm');
    const matches = [...source.matchAll(pattern)];
    if (matches.length !== 1 || !matches[0][0].includes("syntax function to_int") ||
        /\b(remove|axiom)\b/.test(matches[0][0])) {
      throw new Error("Unexpected Why3 driver layout: Float" + width + " conversion");
    }
    source = source.replace(pattern, '(* Native Float' + width + ' to_int encoding omitted. *)');
  }
  return source.replace(/^import "([^"]+)"$/gm, (_, name) => 'import ' + JSON.stringify(join(directory, name)));
}

// Definitions remain equivalent axioms rather than SMT define-fun expansions.
// This preserves predicate names for matching quantified standard-library laws.
export function quantifiedDriver(source) {
  const before = 'transformation "eliminate_definition_conditionally"';
  if (source.split(before).length !== 2) throw new Error("Unexpected Why3 driver layout: definitions");
  return source.replace(before, 'transformation "eliminate_definition"');
}

export function cvc5RealDriver(source, directory) {
  const line = 'import "smt-libv2-floats.gen"';
  if (source.split(line).length !== 2) throw new Error("Unexpected Why3 driver layout: CVC5 floats");
  return source.replace(line, '(* Retain the upstream real-valued IEEE model. *)')
    .replace(/^import "([^"]+)"$/gm, (_, name) => 'import ' + JSON.stringify(join(directory, name)));
}

export function configureWhy3() {
  const moonDirectory = join(homedir(), ".moon");
  const dataDirectory = join(moonDirectory, "share/why3");
  const drivers = join(dataDirectory, "drivers");
  const output = fileURLToPath(new URL("../_build/why3/", import.meta.url));
  mkdirSync(output, {recursive: true});
  const driver = join(output, "z3-arithmetic.drv");
  writeFileSync(driver, arithmeticDriver(readFileSync(join(drivers, "z3_487.drv"), "utf8"), drivers));
  const floatDriver = join(output, "z3-real-float.drv");
  writeFileSync(floatDriver, realFloatDriver(readFileSync(join(drivers, "z3_487.drv"), "utf8"), drivers));
  const quantified = join(output, "z3-quantified.drv");
  writeFileSync(quantified, quantifiedDriver(readFileSync(floatDriver, "utf8")));
  const cvc5Driver = join(output, "cvc5-real.drv");
  writeFileSync(cvc5Driver, cvc5RealDriver(readFileSync(join(drivers, "cvc5.drv"), "utf8"), drivers));
  const cvc5 = installedCvc5();
  const cvc5Command = "'" + cvc5.command.replaceAll("'", "'\\''") + "' --stats-internal --tlimit=%T %f";
  const version = execFileSync("z3", ["-version"], {encoding: "utf8"}).match(/^Z3 version (\d+\.\d+\.\d+)\b/)?.[1];
  if (!version) throw new Error("Unrecognized Z3 version");
  const config = join(output, "why3.conf");
  const strategy = [
    "start:",
    "c Z3," + version + " .2 1000",
    "c Z3-Arithmetic," + version + " .2 1000",
    "c CVC5," + cvc5.version + " .2 1000",
    "c Z3-RealFloat," + version + " .2 1000",
    "c Z3-Quantified," + version + " .2 1000",
    "c Z3," + version + " 1 1000",
    "c Z3-Arithmetic," + version + " 1 1000",
    "c CVC5," + cvc5.version + " 1 1000",
    "c Z3-RealFloat," + version + " 1 1000",
    "c Z3-Quantified," + version + " 1 1000",
    "t compute_specified start",
    "t split_vc start",
    // Normalize concrete datatype constructors after splitting. Doing this
    // earlier can obscure the recursive hypotheses needed by list proofs.
    "t compute_in_goal start",
    "c Z3," + version + " 2 4000",
    "c Z3-Arithmetic," + version + " 2 4000",
    "c CVC5," + cvc5.version + " 2 4000",
    "c Z3-RealFloat," + version + " 2 4000",
    "c Z3-Quantified," + version + " 2 4000",
    "",
  ].join("\n");
  writeFileSync(config, '[main]\nmagic = 14\ndatadir = ' + JSON.stringify(dataDirectory) +
    '\nlibdir = ' + JSON.stringify(join(moonDirectory, "lib/why3")) +
    '\nmemlimit = 1000\nrunning_provers_max = 16\ntimelimit = 5.0\n\n' +
    '[prover]\nname = "Z3"\nversion = "' + version + '"\ncommand = "z3 -smt2 -T:%t %f"\ndriver = "z3_487"\n\n' +
    '[prover]\nname = "Z3-Arithmetic"\nversion = "' + version + '"\ncommand = "z3 -smt2 -T:%t %f"\ndriver = ' + JSON.stringify(driver) + '\n\n' +
    '[prover]\nname = "Z3-RealFloat"\nversion = "' + version + '"\ncommand = "z3 -smt2 -T:%t %f"\ndriver = ' + JSON.stringify(floatDriver) + '\n\n' +
    '[prover]\nname = "Z3-Quantified"\nversion = "' + version + '"\ncommand = "z3 -smt2 -T:%t %f"\ndriver = ' + JSON.stringify(quantified) + '\n\n' +
    '[prover]\nname = "CVC5"\nversion = "' + cvc5.version + '"\ncommand = ' + JSON.stringify(cvc5Command) + '\ndriver = ' + JSON.stringify(cvc5Driver) + '\n\n' +
    '[strategy]\nname = "MoonBit_Auto"\ndesc = "Native SMT, quantified laws and real-valued IEEE models"\nshortcut = "4"\ncode = ' +
    '"' + strategy.replaceAll('"', '\\"') + '"\n');
  return config;
}
