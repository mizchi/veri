export const catalog = new Map([
  ["list/reverse-to-array", ["core-list"]],
  ["list/append-to-array", ["core-list"]],
  ["list/length", ["core-list"]],
  ["stack/build-drain", ["core-list", "core-array"]],
  ["queue/build-drain", ["core-queue"]],
  ["queue/repeated-peek", ["core-queue"]],
  ["pqueue/build-drain-shuffled", ["core-immut-pqueue", "core-pqueue"]],
  ["bst/build-find-shuffled", ["core-immut-sorted-set"]],
  ["pqueue/build-drain-ascending", ["core-immut-pqueue", "core-pqueue"]],
  ["bst/build-find-ascending", ["core-immut-sorted-set"]],
  ["tree/inorder-to-array-balanced", ["core-immut-sorted-set"]],
  ["tree/inorder-to-array-left-skewed", ["core-immut-sorted-set"]],
  ["tree/to-array-balanced", ["core-immut-sorted-set"]],
  ["tree/to-array-left-skewed", ["core-immut-sorted-set"]],
]);

export function parseSummaries(output) {
  const rows = [];
  const names = new Set();
  for (const line of output.split(/\r?\n/)) {
    if (!line.startsWith("VERI_BENCH_JSON ")) continue;
    const batch = JSON.parse(line.slice("VERI_BENCH_JSON ".length));
    if (!Array.isArray(batch)) throw new Error("Expected a benchmark JSON array");
    for (const row of batch) {
      if (typeof row.name !== "string") throw new Error("Unnamed benchmark");
      if (names.has(row.name)) throw new Error("Duplicate benchmark: " + row.name);
      names.add(row.name);
      rows.push(row);
    }
  }
  if (!rows.length) throw new Error("No benchmark summaries found");
  return rows;
}

function positive(value) {
  if (!Number.isFinite(value) || value <= 0) throw new Error("Expected a finite positive timing or limit");
}

export function comparePair(veri, core) {
  if (veri.length !== 2 || core.length !== 2) throw new Error("Expected two passes per implementation");
  [...veri, ...core].forEach(positive);
  const veri_us = (veri[0] + veri[1]) / 2;
  const core_us = (core[0] + core[1]) / 2;
  return {
    veri_us, core_us,
    ratio: veri_us / core_us,
    pass_ratios: veri.map((value, index) => value / core[index]),
  };
}

export function checkLimit(row, limit) {
  positive(limit);
  if (row.pass_ratios.every(ratio => ratio <= limit)) return "within";
  if (row.pass_ratios.every(ratio => ratio > limit)) return "slower";
  return "inconclusive";
}

export function analyzeResults(summaries) {
  const byName = new Map(summaries.map(row => [row.name, row]));
  if (byName.size !== summaries.length) throw new Error("Duplicate benchmark summaries");
  const consumed = new Set();
  const timing = name => {
    const row = byName.get(name);
    if (!row) throw new Error("Missing benchmark: " + name);
    if (row.runs !== 5 || !Number.isInteger(row.batch_size) || row.batch_size < 1) {
      throw new Error("Unexpected benchmark sampling: " + name);
    }
    positive(row.median);
    consumed.add(name);
    return row.median;
  };
  const results = [];
  for (const n of [256, 2048]) {
    for (const [scenario, baselines] of catalog) {
      const samples = implementation => [0, 1].map(pass => timing(`${scenario}|n=${n}|${implementation}|pass=${pass}`));
      const veri = samples("veri");
      for (const baseline of baselines) {
        const row = {scenario, n, baseline, ...comparePair(veri, samples(baseline))};
        results.push({...row, versus_equal_time: checkLimit(row, 1)});
      }
    }
  }
  if (consumed.size !== byName.size) throw new Error("Unexpected benchmark summaries");
  return results;
}

export function renderReport(report) {
  const {environment, results, limit} = report;
  const lines = [
    "# Collection benchmark results", "",
    `Recorded: ${environment.timestamp}. Target: ${environment.target}, release.`,
    `CPU: ${environment.cpu}. OS: ${environment.platform} ${environment.os_release} (${environment.arch}).`,
    `Node: ${environment.node}. Repository base: ${environment.commit} (working tree dirty: ${environment.dirty}).`,
    `Moon: ${environment.moon.replaceAll("\n", " ")}.`,
    `Installed core source SHA-256: ${environment.core_sha256}.`,
    ...(environment.runtime_sha256 ? [`Runtime source SHA-256: ${environment.runtime_sha256}.`, `Benchmark source SHA-256: ${environment.workloads_sha256}.`] : []), "",
    ...(environment.imported_log ? ["Imported local moon bench output; environment metadata was captured when importing.", ""] : []),
    "Times are microseconds per complete workload: the mean of two batch medians.",
    "Each pass contains five calibrated batches; implementation order is reversed in pass 2.",
    "Ratios are veri/core (above 1 means slower). The range shows the two paired ratios, not a confidence interval.",
    "These measurements compare the current data structures, including representation and allocation costs; they do not isolate proof-contract overhead.", "",
    "| Workload | n | Core baseline | veri µs | core µs | Ratio | Paired range | Compared with 1.0 |",
    "| --- | ---: | --- | ---: | ---: | ---: | ---: | --- |",
  ];
  for (const row of results) {
    const range = `${Math.min(...row.pass_ratios).toFixed(2)}–${Math.max(...row.pass_ratios).toFixed(2)}`;
    lines.push(`| ${row.scenario} | ${row.n} | ${row.baseline} | ${row.veri_us.toFixed(3)} | ${row.core_us.toFixed(3)} | ${row.ratio.toFixed(2)}× | ${range} | ${row.versus_equal_time} |`);
  }
  lines.push("", "`within` means both paired ratios are ≤ 1; `slower` means both are > 1; otherwise `inconclusive`.");
  if (limit !== null) {
    const failed = results.filter(row => checkLimit(row, limit) !== "within");
    lines.push("", `Requested ratio limit: ${limit}. ${failed.length} of ${results.length} comparisons do not establish non-regression.`);
  }
  return lines.join("\n") + "\n";
}
