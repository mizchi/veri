import assert from "node:assert/strict";
import test from "node:test";
import { analyzeSmtlib, renderSmtlib } from "./bench-smtlib-results.mjs";

const row = (name, median) => ({name, median});

test("pairs reference and tuned passes and reports speedups", () => {
  const results = analyzeSmtlib([
    row("encode|n=1|reference|pass=0", 400),
    row("encode|n=1|tuned|pass=0", 100),
    row("encode|n=1|tuned|pass=1", 100),
    row("encode|n=1|reference|pass=1", 200),
    row("eval|n=1|tuned|pass=0", 30),
    row("eval|n=1|tuned|pass=1", 50),
  ]);
  assert.deepEqual(results, [
    {name: "encode|n=1", reference_us: 300, tuned_us: 100, speedup: 3, pass_speedups: [4, 2]},
    {name: "eval|n=1", tuned_us: 40},
  ]);
  const report = renderSmtlib({environment: {target: "native"}, results});
  assert.match(report, /\| `encode\|n=1` \| 300\.0 µs \| 100\.0 µs \| 3\.00× \| 2\.00–4\.00 \|/);
  assert.match(report, /\| `eval\|n=1` \| — \| 40\.0 µs \| — \| — \|/);
});

test("rejects incomplete or malformed measurements", () => {
  assert.throws(() => analyzeSmtlib([row("encode|tuned|pass=0", 1)]), /two tuned passes/);
  assert.throws(() => analyzeSmtlib([
    row("encode|tuned|pass=0", 1), row("encode|tuned|pass=1", 1), row("encode|reference|pass=0", 1),
  ]), /two reference passes/);
  assert.throws(() => analyzeSmtlib([row("encode|tuned|pass=0", 0)]), /positive/);
  assert.throws(() => analyzeSmtlib([row("encode|other|pass=0", 1)]), /Unexpected benchmark name/);
  assert.throws(() => analyzeSmtlib([row("encode|tuned|pass=0", 1), row("encode|tuned|pass=0", 1)]), /Duplicate pass/);
});
