import assert from "node:assert/strict";
import { test } from "node:test";
import { expectStatus } from "./solver.mjs";

test("unproved results must fail the verification command", () => {
  for (const output of ["unknown\n", "sat\n", "", "(error \"bad input\")\nunsat\n", "unsat\nsat\n"]) {
    assert.throws(() => expectStatus(output, "unsat"));
  }
  assert.equal(expectStatus("unsat\n", "unsat"), "unsat");
});

test("counterexample checks must find a witness", () => {
  assert.throws(() => expectStatus("unsat\n", "sat"));
  assert.equal(expectStatus("sat\n((left 0.5) (right 0.0))\n", "sat"), "sat");
});
