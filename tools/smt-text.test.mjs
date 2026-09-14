import test from "node:test";
import assert from "node:assert/strict";
import { encodeSmtText, decodeSmtText } from "./smt-text.mjs";
import { runZ3 } from "./solver.mjs";

test("SMT string reference round-trips quotes, literal escapes, and Unicode boundaries", () => {
  for (const input of ["", '"', "\0\n", "\\u{41}", "😀é", "\ud7ff\ue000\u{2ffff}"]) {
    const answer = runZ3("(simplify " + encodeSmtText(input) + ")").trim();
    assert.equal(decodeSmtText(answer), input);
  }
});

test("reject characters the shared alphabet cannot represent", () => {
  for (const value of ["\ud800", "\udfff", "\u{30000}", "\u{10ffff}"]) {
    assert.throws(() => encodeSmtText(value), /shared alphabet/);
  }
  assert.throws(() => decodeSmtText('(error "failed")'), /Invalid string reference/);
  assert.equal(decodeSmtText('"\\u0041"'), "A");
});
