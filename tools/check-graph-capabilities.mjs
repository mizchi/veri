import { mkdtempSync, writeFileSync, readFileSync, rmSync, mkdirSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

// Positive probes consume the public soundness contracts. ArrayView adapters
// deliberately use true: they report lowering support, not semantic soundness.
const probes = [
  ["bfs-checker", "search : @graph.SearchResult", "graph.check_bfs(search)",
    "accepted => accepted → @graph.certified(graph, search, false)", "accepted"],
  ["dijkstra-checker", "search : @graph.SearchResult", "graph.check_dijkstra(search)",
    "accepted => accepted → @graph.certified(graph, search, true)", "accepted"],
  ["bfs-shortest", "search : @graph.SearchResult, vertex : Int", "graph.check_bfs(search)",
    "accepted => accepted → @graph.shortest_at(graph, search, vertex, false)", "accepted"],
  ["dijkstra-shortest", "search : @graph.SearchResult, vertex : Int", "graph.check_dijkstra(search)",
    "accepted => accepted → @graph.shortest_at(graph, search, vertex, true)", "accepted"],
  ["topological-checker", "order : FixedArray[Int]", "graph.check_topological_order(order)",
    "accepted => accepted → @graph.topological_order(graph, order)", "accepted"],
  ["topological-acyclic", "order : FixedArray[Int]", "graph.check_topological_order(order)",
    "accepted => accepted → @graph.acyclic(graph)", "accepted"],
  ["cycle-checker", "cycle : FixedArray[Int]", "graph.check_cycle(cycle)",
    "accepted => accepted → @graph.simple_cycle(graph, cycle)", "accepted"],
  ["cycle-cyclic", "cycle : FixedArray[Int]", "graph.check_cycle(cycle)",
    "accepted => accepted → (@graph.cyclic(graph) && !@graph.acyclic(graph))", "accepted"],
  ["topology-verdict", "topology : @graph.Topology", "graph.check_topology(topology)",
    "accepted => accepted → @graph.valid_topology(graph, topology)", "accepted"],
  ["topological-view-adapter", "order : ArrayView[Int]", "graph.check_topological_order_view(order)",
    "_result => true", "unsupported"],
  ["cycle-view-adapter", "cycle : ArrayView[Int]", "graph.check_cycle_view(cycle)",
    "_result => true", "unsupported"],
];
const reports = [];
for (const [name, parameter, expression, postcondition, expected] of probes) {
  const directory = mkdtempSync(join(tmpdir(), "veri-graph-capability-"));
  const source = `pub fn probe(graph : @graph.Graph, ${parameter}) -> Bool where {
  proof_ensure: ${postcondition},
} { ${expression} }
`;
  const imports = '"mizchi/veri/runtime/graph"';
  try {
    writeFileSync(join(directory, "moon.mod"), 'name = "mizchi/graph-capability"\nimport { "mizchi/veri@0.1.0" }\n');
    writeFileSync(join(directory, "moon.work"), 'members = [".", ' + JSON.stringify(fileURLToPath(new URL("../", import.meta.url))) + ']\n');
    writeFileSync(join(directory, "moon.pkg"), `import { ${imports} }\noptions("proof-enabled": true)\n`);
    writeFileSync(join(directory, "probe.mbt"), source);
    const check = spawnSync("moon", ["check", "--deny-warn"], {cwd: directory, encoding: "utf8", timeout: 30000});
    if (check.error) throw check.error;
    if (check.status !== 0) throw new Error(`Invalid probe: ${check.stdout}${check.stderr}`);
    const proof = spawnSync("moon", ["prove"], {cwd: directory, encoding: "utf8", timeout: 30000});
    if (proof.error) throw proof.error;
    const diagnostics = proof.stdout + proof.stderr;
    let status;
    if (proof.status === 0) {
      const report = JSON.parse(readFileSync(join(directory, "_build/verif/graph-capability.proof.json"), "utf8"));
      if (report.result !== "success" || report.summary.valid < 1) throw new Error("Missing proof report");
      status = "accepted";
    } else if (diagnostics.includes("Error: [4207]") && diagnostics.includes("only contracted functions")) {
      status = "unsupported";
    } else { throw new Error(`Unexpected ${name}: ${diagnostics}`); }
    if (expected === "accepted" && status !== "accepted") {
      throw new Error(`Public checker contract regressed: ${name}\n${diagnostics}`);
    }
    reports.push({name, source, status, soundnessContractConsumed: expected === "accepted", diagnostics});
    console.log(`${name}: ${status}; ${expected === "accepted" ? "public soundness contract proved" : "lowering probe only"}.`);
  } finally { rmSync(directory, {recursive:true, force:true}); }
}
const version = spawnSync("moon", ["version", "--all"], {encoding:"utf8"});
if (version.error || version.status !== 0) throw new Error("Cannot record MoonBit version");
mkdirSync(new URL("../_build/", import.meta.url), {recursive:true});
writeFileSync(new URL("../_build/graph-capabilities.json", import.meta.url), JSON.stringify({toolchain:version.stdout.trim(), probes:reports}, null, 2) + "\n");
