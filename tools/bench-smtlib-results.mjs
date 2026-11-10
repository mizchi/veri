// Pairs "reference" and "tuned" variants of the benchmarks/smtlib workloads.
// A benchmark is named `workload|parameter|variant|pass=N`; each variant runs
// in two passes with the variant order reversed.

function positive(value) {
  if (!Number.isFinite(value) || value <= 0) throw new Error("Expected a finite positive timing");
  return value;
}

export function analyzeSmtlib(summaries) {
  const workloads = new Map();
  for (const row of summaries) {
    const match = /^(.+)\|(reference|tuned)\|pass=([01])$/.exec(row.name);
    if (!match) throw new Error("Unexpected benchmark name: " + row.name);
    const [, name, variant, pass] = match;
    if (!workloads.has(name)) workloads.set(name, {reference: [], tuned: []});
    const passes = workloads.get(name)[variant];
    if (passes[Number(pass)] !== undefined) throw new Error("Duplicate pass: " + row.name);
    passes[Number(pass)] = positive(row.median);
  }
  const results = [];
  for (const [name, {reference, tuned}] of workloads) {
    if (tuned.length !== 2 || tuned.includes(undefined)) throw new Error("Expected two tuned passes: " + name);
    const tuned_us = (tuned[0] + tuned[1]) / 2;
    if (reference.length === 0) {
      results.push({name, tuned_us});
      continue;
    }
    if (reference.length !== 2 || reference.includes(undefined)) throw new Error("Expected two reference passes: " + name);
    const reference_us = (reference[0] + reference[1]) / 2;
    // Above 1 means the tuned implementation is faster.
    const pass_speedups = reference.map((value, pass) => value / tuned[pass]);
    results.push({name, reference_us, tuned_us, speedup: reference_us / tuned_us, pass_speedups});
  }
  return results;
}

function time(us) {
  return us >= 1000 ? (us / 1000).toFixed(2) + " ms" : us.toFixed(1) + " µs";
}

export function renderSmtlib({environment, results}) {
  const lines = [
    `# SMT-LIB benchmarks (${environment.target})`,
    "",
    "Times are the mean of the two pass medians. Speedup is reference / tuned, so values",
    "above 1 mean the tuned implementation is faster; the range covers both measurement orders.",
    "",
    "| Workload | Reference | Tuned | Speedup | Range |",
    "| --- | ---: | ---: | ---: | ---: |",
  ];
  for (const result of results) {
    if (result.speedup === undefined) {
      lines.push(`| \`${result.name}\` | — | ${time(result.tuned_us)} | — | — |`);
    } else {
      const [low, high] = [Math.min(...result.pass_speedups), Math.max(...result.pass_speedups)];
      lines.push(`| \`${result.name}\` | ${time(result.reference_us)} | ${time(result.tuned_us)} | ${result.speedup.toFixed(2)}× | ${low.toFixed(2)}–${high.toFixed(2)} |`);
    }
  }
  lines.push("", "```text");
  for (const [key, value] of Object.entries(environment)) {
    lines.push(`${key}: ${Array.isArray(value) ? value.join(" ") : String(value).replace(/\s+/g, " ")}`);
  }
  lines.push("```", "");
  return lines.join("\n");
}
