import { strict as assert } from "node:assert";
import { execFileSync } from "node:child_process";
import { mkdtempSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

// Exercise the published contents and the exact README quickstart in a fresh
// workspace. Nothing is uploaded and the checkout is not used as a dependency.
const root = fileURLToPath(new URL("../", import.meta.url));
const manifest = readFileSync(join(root, "moon.mod"), "utf8");
const name = manifest.match(/^name = "([^"]+)"$/m)?.[1];
const version = manifest.match(/^version = "([^"]+)"$/m)?.[1];
assert.ok(name && version, "Missing package name/version");
assert.match(manifest, /^license = "Apache-2.0"$/m);

function run(command, args, cwd) {
  return execFileSync(command, args, {cwd, encoding: "utf8", maxBuffer: 16 * 1024 * 1024});
}

function quickstart(file) {
  const section = readFileSync(join(root, file), "utf8").split("## QuickStart\n")[1]?.split("\n## ")[0];
  assert.ok(section, `Missing QuickStart section in ${file}`);
  const blocks = [...section.matchAll(/```moonbit\n([\s\S]*?)\n```/g)].map(match => match[1]);
  assert.equal(blocks.length, 2, `Expected import and source examples in ${file}`);
  return blocks;
}

const blocks = quickstart("README.md");
assert.deepEqual(blocks, quickstart("README.ja.md"));
process.stdout.write(run("moon", ["package"], root));
const archive = join(root, "_build", "publish", `${name.replaceAll("/", "-")}-${version}.zip`);
const entries = run("unzip", ["-Z1", archive], root).trim().split("\n");
for (const guide of ["packages", "toolkit", "collections", "numerics", "verification",
  "benchmarks", "architecture", "floating-point", "temporal", "model-workflows"]) {
  for (const suffix of [".md", ".ja.md"]) {
    const file = `docs/${guide}${suffix}`;
    assert.ok(entries.includes(file), `Missing packaged guide: ${file}`);
  }
}
for (const required of ["LICENSE", "README.md", "README.ja.md", "moon.mod",
  "runtime/array/range.mbt", "runtime/queue/iter.mbt", "strings/strings.mbtp",
  "bitvector/bv32.mbtp", "bitvector/bv8.mbtp", "bitvector/bv16.mbtp",
  "runtime/int32/checked.mbt", "runtime/int64/checked.mbt", "runtime/conversion/conversion.mbt",
  "runtime/bytes/codec.mbt", "encoding/encoding.mbtp", "algebra/algebra.mbtp",
  "graph/graph.mbtp", "runtime/graph/graph.mbt",
  "runtime/map/map.mbt", "runtime/set/set.mbt", "runtime/search/search.mbt",
  "runtime/union_find/union_find.mbt", "union_find/partition.mbtp",
  "runtime/graph/checker/relaxation.mbt", "runtime/graph/checker/soundness.mbtp",
  "runtime/graph/checker/certificate.mbt", "runtime/graph/certificate.mbtp",
  "runtime/graph/topology/order.mbt", "runtime/graph/topology/cycle.mbt",
  "runtime/graph/topology/soundness.mbtp", "runtime/graph/topology.mbtp", "runtime/bytes/cursor/cursor.mbt",
  "model_check/types.mbt", "model_check/driver/driver.mbt", "model_check/smt/encode.mbt",
  "model_check/runner/runner.mbt", "cmd/model-check/main.mbt",
  "model_check/builder.mbt", "model_check/suite/types.mbt", "model_check/runner/artifact.mbt",
  "model_check/runner/solver.mbt", "model_check/smt/exhaustive.mbt", "model_check/smt/response.mbt",
  "testing/state_machine/replay.mbt", "testing/state_machine/async/replay.mbt"]) {
  assert.ok(entries.includes(required), `Missing packaged file: ${required}`);
}
for (const entry of entries) {
  assert.ok(!/^(?:_build\/|examples\/|benchmarks\/|checks\/|tools\/|\.git\/|moon\.work$|TODO\.md$|veri\.mbtx$)/.test(entry),
    `Development file in package: ${entry}`);
}

const directory = mkdtempSync(join(tmpdir(), "veri-package-"));
try {
  run("unzip", ["-q", archive, "-d", join(directory, "dependency")], root);
  const consumer = join(directory, "consumer");
  mkdirSync(consumer);
  writeFileSync(join(directory, "moon.work"), 'members = ["consumer", "dependency"]\n');
  writeFileSync(join(consumer, "moon.mod"),
    `name = "package-check/consumer"\nversion = "0.0.0"\nimport { "${name}@${version}" }\n`);
  writeFileSync(join(consumer, "moon.pkg"), blocks[0] + "\n");
  writeFileSync(join(consumer, "digit.mbt"), blocks[1] + "\n");
  const toolkit = join(consumer, "toolkit");
  mkdirSync(toolkit);
  writeFileSync(join(toolkit, "moon.pkg"), `import {
    "mizchi/veri/runtime/map",
    "mizchi/veri/runtime/set",
    "mizchi/veri/runtime/search",
    "mizchi/veri/runtime/union_find",
    "mizchi/veri/runtime/bytes/cursor",
    "mizchi/veri/runtime/int32",
    "mizchi/veri/runtime/int64",
    "mizchi/veri/runtime/conversion",
    "mizchi/veri/runtime/bytes",
    "mizchi/veri/runtime/list",
    "mizchi/veri/runtime/stack",
    "mizchi/veri/runtime/bintree",
    "mizchi/veri/runtime/graph",
  } for "test"
`);
  writeFileSync(join(toolkit, "toolkit_test.mbt"), `test "packaged toolkit APIs compose" {
    let map : @map.Map[Int, Int] = Map([(1, 2)])
    let set : @set.Set[Int] = Set([1])
    assert_true(@map.matches_entries(map, [(1, 2)]))
    assert_true(@set.matches_elements(set, [1]))
    assert_eq(@search.lower_bound([1, 2, 2], 2), 1)
    let uf = @union_find.UnionFind::new(2)
    assert_true(uf.union(0, 1))
    assert_true(uf.same(0, 1))
    let (byte, rest) = @cursor.Cursor::new(b"x"[:]).read(@cursor.byte()).unwrap()
    assert_eq(byte, b'x')
    assert_eq(rest.remaining(), 0)
    assert_eq(@int32.checked_add(2147483647, 1), None)
    assert_eq(@int64.checked_mul(6L, 7L), Some(42L))
    assert_eq(@conversion.checked_int_to_uint(-1), None)
    assert_eq(@conversion.uint_to_int64(4294967295U), 4294967295L)
    let encoded = @bytes.uint16_to_be_bytes(UInt16(4660))
    assert_eq(encoded, b"\\x12\\x34")
    assert_eq(@bytes.decode_uint16_be(encoded[:], 0).unwrap().next_offset, 2)
    assert_eq(@bytes.read_uint16_be(encoded[:], 0), Some(UInt16(4660)))
    let xs = @list.List::from_iter([1, 2, 3].iter())
    assert_eq(xs.map(x => x * 2).fold(init=0, (a, b) => a + b), 12)
    let stack = @stack.Stack::new().push(1).push(2)
    let (top, rest) = stack.pop().unwrap()
    assert_eq(top, 2)
    assert_eq(rest.to_array(), [1])
    assert_eq(stack.to_array(), [2, 1])
    let tree = @bintree.Tree::node(@bintree.Tree::new(), 7, @bintree.Tree::new())
    assert_eq(tree.to_array(), [7])
    let graph = @graph.Graph::from_array([{ from: 0, to: 1, weight: 7 }], vertex_count=2)
    assert_eq(graph.bfs(0).distance(1), Some(1))
    let result = graph.dijkstra(0)
    assert_eq(result.distance(1), Some(7))
    assert_true(graph.check_dijkstra(result))
    assert_true(graph.check_topology(graph.topological_sort()))
    let cyclic = @graph.Graph::from_array([{ from: 0, to: 0, weight: 0 }], vertex_count=1)
    assert_true(cyclic.check_topology(cyclic.topological_sort()))
    let copy = @graph.Graph::from_iter(graph.iter(), vertex_count=2)
    assert_eq(copy.to_array(), graph.to_array())
  }
`);
  process.stdout.write(run("moon", ["test", "toolkit", "--target", "js", "--deny-warn"], consumer));
  process.stdout.write(run("moon", ["test", ".", "--target", "js", "--deny-warn"], consumer));
  process.stdout.write(run("moon", ["prove", ".", "--deny-warn"], consumer));
  const graphContracts = join(consumer, "graph-contracts");
  mkdirSync(graphContracts);
  writeFileSync(join(graphContracts, "moon.pkg"), `import { "mizchi/veri/runtime/graph" }
options("proof-enabled": true)
`);
  writeFileSync(join(graphContracts, "client.mbt"), readFileSync(join(root, "examples/toolkit/checked_graph.mbt")));
  process.stdout.write(run("moon", ["prove", "graph-contracts", "--deny-warn"], consumer));
  // Exercise the packaged CLI and protocol from a separate consumer model.
  const modelDriver = join(consumer, "model-driver");
  mkdirSync(modelDriver);
  writeFileSync(join(modelDriver, "moon.pkg"), `import {
    "mizchi/veri/model_check",
    "mizchi/veri/model_check/driver",
  }
  pkgtype(kind: "executable")
`);
  writeFileSync(join(modelDriver, "main.mbt"), `fn client(_config : Json) -> @model_check.Client[Int, Int, Int] {
    {
      initial: 0, states: [0, 1], events: [0],
      step: (_, _) => Some(1),
      holds: (s, name) => if name == "safe" { Some(s == 0) } else { None },
      model: {
        initial: 0, actions: ["advance"], states: [0, 1], transitions: [[1], [1]],
        predicates: { "safe": [true, false] }, justice: [], exploration: None,
      },
    }
  }
  fn main { @driver.serve(client) }
`);
  const cliResult = JSON.parse(run("moon", ["run", "cmd/model-check", "--target", "wasm", "--deny-warn", "--",
    "check", "model-driver", "--module", consumer, "--safety", "safe", "--bound", "1"], join(directory, "dependency")));
  assert.equal(cliResult.result, "counterexample");
  assert.equal(cliResult.bound, 1);
  assert.deepEqual(cliResult.witness, {states: [0, 1], actions: [0]});
  const suitePath = join(consumer, "suite.json");
  writeFileSync(suitePath, JSON.stringify({version:1,cases:[{
    name:"packaged workflow",driver:"model-driver",module_dir:".",
    property:{kind:"safety",predicate:"safe"},bound:1,expect:"counterexample",
  }]}));
  const suiteResult = JSON.parse(run("moon", ["run", "cmd/model-check", "--target", "wasm", "--deny-warn", "--",
    "test", suitePath], join(directory,"dependency")));
  assert.equal(suiteResult.passed,true);
  const workflow = join(consumer,"workflow");
  mkdirSync(workflow);
  writeFileSync(join(workflow,"moon.pkg"), `import {
    "mizchi/veri/model_check",
    "mizchi/veri/testing/state_machine",
  } for "test"
`);
  writeFileSync(join(workflow,"workflow_test.mbt"), `test "packaged workflow APIs" {
    let model : @state_machine.Model[Int,Int,Int,Int] = {
      initial:() => 0, step:(s,c) => Some((s+c,s+c)), observe:s => s,
    }
    let system : @state_machine.System[Int,Int,Int,Int] = {
      create:() => 0, step:(s,c) => (s+c,s+c), observe:s => s, close:_ => (),
    }
    @state_machine.check(model,system,count=10,seed=20260916)
    let spec : @model_check.Spec[Int,Int,Int] = {
      initial:0,actions:[("finish",1)],step:(_,_) => Some(1),
      predicates:[("safe",s => s==0)],snapshot:s => s,justice:[],
    }
    let client = @model_check.build_client(spec,max_depth=1,state_hash=s => s)
    assert_true(client.accepts(Safety("safe"),{states:[0,1],actions:[0],loop_start:None}))
  }
`);
  process.stdout.write(run("moon",["test","workflow","--target","js","--deny-warn"],consumer));
  console.log("Packaged MoonBit CLI checks, replays, and runs suites against a separate consumer model.");
  console.log(`Packaged ${entries.length} files; both README quickstarts execute and prove.`);
} finally {
  rmSync(directory, {recursive: true, force: true});
}
