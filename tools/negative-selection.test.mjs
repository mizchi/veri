import test from "node:test";
import assert from "node:assert/strict";
import { selectNegativeChecks } from "./negative-selection.mjs";

test("negative selection retains every width and rejects unknown packages", () => {
  const checks = [{package: "bitvector", width: 32}, {package: "real"}, {package: "bitvector", width: 64}];
  assert.deepEqual(selectNegativeChecks(checks, []), checks);
  assert.deepEqual(selectNegativeChecks(checks, ["bitvector"]), [checks[0], checks[2]]);
  assert.deepEqual(selectNegativeChecks(checks, ["bitvector", "bitvector"]), [checks[0], checks[2]]);
  assert.throws(() => selectNegativeChecks(checks, ["bitvector", "missing"]), /Unknown negative-control package: missing/);
});
