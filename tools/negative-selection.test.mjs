import test from "node:test";
import assert from "node:assert/strict";
import { selectNegativeChecks, shardNegativeChecks } from "./negative-selection.mjs";

test("negative shards cover each control exactly once and reject bad indices", () => {
  const checks = Array.from({length:68},(_,id)=>({id}));
  const shards = Array.from({length:4},(_,shard)=>shardNegativeChecks(checks,shard,4));
  assert(shards.every(part => part.length === 17));
  assert.deepEqual(shards.flat().sort((a,b)=>a.id-b.id),checks);
  for(const [shard,total] of [[-1,4],[4,4],[0,0],[0,1.5],[NaN,4],[0,100]]) {
    assert.throws(()=>shardNegativeChecks(checks,shard,total), /Invalid/);
  }
});

test("negative selection retains every width and rejects unknown packages", () => {
  const checks = [{package: "bitvector", width: 32}, {package: "real"}, {package: "bitvector", width: 64}];
  assert.deepEqual(selectNegativeChecks(checks, []), checks);
  assert.deepEqual(selectNegativeChecks(checks, ["bitvector"]), [checks[0], checks[2]]);
  assert.deepEqual(selectNegativeChecks(checks, ["bitvector", "bitvector"]), [checks[0], checks[2]]);
  assert.throws(() => selectNegativeChecks(checks, ["bitvector", "missing"]), /Unknown negative-control package: missing/);
});
