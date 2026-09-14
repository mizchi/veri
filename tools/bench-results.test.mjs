import test from "node:test";
import assert from "node:assert/strict";
import { parseSummaries, comparePair, checkLimit, analyzeResults, catalog } from "./bench-results.mjs";

const summary = (name, median) => ({name, median, mean: median, min: median, max: median, runs: 5, batch_size: 10});

test("benchmark summaries retain unrounded microseconds and reject broken output", () => {
  const row = summary("list/length|n=256|veri|pass=0", 0.123456);
  assert.deepEqual(parseSummaries('compiler output\nVERI_BENCH_JSON ' + JSON.stringify([row]) + '\ntable'), [row]);
  assert.throws(() => parseSummaries('VERI_BENCH_JSON [{'), /JSON/);
  assert.throws(() => parseSummaries('all benchmarks passed'), /No benchmark/);
  assert.throws(() => parseSummaries('VERI_BENCH_JSON ' + JSON.stringify([row, row])), /Duplicate/);
});

test("slower means greater elapsed time and is never a passing non-regression check", () => {
  const rows = comparePair([10, 12], [2, 3]);
  assert.equal(rows.ratio, 4.4);
  assert.deepEqual(rows.pass_ratios, [5, 4]);
  assert.equal(checkLimit(rows, 1), "slower");
  assert.equal(checkLimit(comparePair([1, 2], [2, 4]), 1), "within");
});

test("order-dependent results are inconclusive and invalid timings cannot pass", () => {
  assert.equal(checkLimit(comparePair([0.9, 1.1], [1, 1]), 1), "inconclusive");
  assert.throws(() => comparePair([1, 1], [0, 1]), /positive/);
  assert.throws(() => comparePair([1, NaN], [1, 1]), /finite/);
  assert.throws(() => comparePair([1], [1, 2]), /two passes/);
  assert.throws(() => checkLimit(comparePair([1, 1], [1, 1]), 0), /positive/);
});

test("a missing size, pass, or baseline prevents a partial report from passing", () => {
  const complete = [];
  for (const n of [256, 2048]) {
    for (const [scenario, baselines] of catalog) {
      for (const implementation of ["veri", ...baselines]) {
        for (const pass of [0, 1]) {
          complete.push(summary(`${scenario}|n=${n}|${implementation}|pass=${pass}`, 1));
        }
      }
    }
  }
  assert.equal(analyzeResults(complete).length, 30);
  assert.throws(() => analyzeResults(complete.slice(1)), /Missing/);
  assert.throws(() => analyzeResults([...complete, summary("unrecognized", 1)]), /Unexpected/);
});
