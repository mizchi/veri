import test from "node:test";
import assert from "node:assert/strict";
import { fpLiteral, referenceBits } from "./fp-reference.mjs";
import { formats } from "./float-cases.mjs";

test("reference oracle distinguishes halfway rounding, signed zero, and NaN at both widths", () => {
  for (const width of [32, 64]) {
    const {bits} = formats[width];
    const fp = key => fpLiteral(width, bits[key]);
    const expressions = [
      "(fp.add RNE " + fp("one") + " " + fp("halfUlp") + ")",
      "(fp.neg " + fp("zero") + ")",
      "(fp.div RNE " + fp("zero") + " " + fp("zero") + ")",
    ];
    assert.deepEqual(referenceBits(width, expressions), [bits.one, bits.negZero, null]);
  }
  assert.throws(() => fpLiteral(32, "3ff0000000000000"), /Invalid/);
  assert.throws(() => fpLiteral(64, "x".repeat(16)), /Invalid/);
});
