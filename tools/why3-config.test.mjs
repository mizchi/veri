import test from "node:test";
import assert from "node:assert/strict";
import { arithmeticDriver } from "./why3-config.mjs";

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
