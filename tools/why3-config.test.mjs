import test from "node:test";
import assert from "node:assert/strict";
import { arithmeticDriver, realFloatDriver, quantifiedDriver, cvc5RealDriver } from "./why3-config.mjs";

test("arithmetic driver changes only the native BV encoding imports", () => {
  const original = 'import "smt-libv2.gen"\nimport "smt-libv2-bv.gen"\nimport "z3_bv.gen"\ntransformation "remove_unused_keep_constants"\ntheory int.Int\n  remove prop CompatOrderMult\nend\n';
  const actual = arithmeticDriver(original, "/why3/drivers");
  assert.ok(actual.includes('import "/why3/drivers/smt-libv2.gen"'));
  assert.ok(actual.endsWith(original.slice(original.indexOf("transformation"))));
  assert.ok(!actual.includes('import "smt-libv2-bv.gen"'));
  assert.ok(!actual.includes('import "z3_bv.gen"'));
  assert.throws(() => arithmeticDriver(original.replace('import "z3_bv.gen"', ''), "/why3"), /Unexpected Why3 driver layout/);
  assert.throws(() => arithmeticDriver(original + 'import "z3_bv.gen"', "/why3"), /Unexpected Why3 driver layout/);
});

test("real float driver retains upstream axioms and removes native FP encodings", () => {
  const source = 'import "smt-libv2.gen"\nimport "smt-libv2-floats.gen"\n' +
    'theory ieee_float.Float64\n syntax function to_int "native64"\nend\n' +
    'theory ieee_float.Float32\n syntax function to_int "native32"\nend\n' +
    'transformation "eliminate_definition_conditionally"\ntransformation "eliminate_literal"\ntheory real.Real\n remove prop add_div\nend\n';
  const actual = realFloatDriver(source, "/why3/drivers");
  assert.ok(actual.includes('import "/why3/drivers/smt-libv2.gen"'));
  assert.ok(!actual.includes("smt-libv2-floats.gen"));
  assert.ok(!actual.includes("native32"));
  assert.ok(!actual.includes("native64"));
  assert.ok(actual.endsWith(source.slice(source.indexOf("transformation"))));
  assert.throws(() => realFloatDriver(source.replace('import "smt-libv2-floats.gen"', ''), "/why3"), /Unexpected Why3 driver layout/);
  assert.throws(() => realFloatDriver(source.replace("ieee_float.Float32", "missing.Float32"), "/why3"), /Unexpected Why3 driver layout/);
  assert.throws(() => realFloatDriver(source.replace('syntax function to_int "native32"', 'remove allprops'), "/why3"), /Unexpected Why3 driver layout/);
});

test("quantified driver changes only the equivalent encoding of definitions", () => {
  const source = 'transformation "inline_trivial"\ntransformation "eliminate_definition_conditionally"\ntransformation "eliminate_literal"\n';
  const actual = quantifiedDriver(source);
  assert.equal(actual, source.replace('"eliminate_definition_conditionally"', '"eliminate_definition"'));
  assert.throws(() => quantifiedDriver(""), /Unexpected Why3 driver layout/);
  assert.throws(() => quantifiedDriver(source + source), /Unexpected Why3 driver layout/);
});

test("CVC5 real driver removes only the native FP fragment", () => {
  const source = 'import "smt-libv2.gen"\nimport "smt-libv2-floats.gen"\ntransformation "inline_trivial"\n';
  const actual = cvc5RealDriver(source, "/why3/drivers");
  assert.ok(actual.includes('import "/why3/drivers/smt-libv2.gen"'));
  assert.ok(!actual.includes("smt-libv2-floats.gen"));
  assert.ok(actual.endsWith('transformation "inline_trivial"\n'));
  assert.throws(() => cvc5RealDriver(source + source, "/why3"), /Unexpected Why3 driver layout/);
});
