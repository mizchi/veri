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

function quickstart(file, endHeading) {
  const section = readFileSync(join(root, file), "utf8").split(endHeading)[0];
  const blocks = [...section.matchAll(/```moonbit\n([\s\S]*?)\n```/g)].map(match => match[1]);
  assert.equal(blocks.length, 2, `Expected import and source examples in ${file}`);
  return blocks;
}

const blocks = quickstart("README.md", "## Verify the repository");
assert.deepEqual(blocks, quickstart("README.ja.md", "## リポジトリを検証する"));
process.stdout.write(run("moon", ["package"], root));
const archive = join(root, "_build", "publish", `${name.replaceAll("/", "-")}-${version}.zip`);
const entries = run("unzip", ["-Z1", archive], root).trim().split("\n");
for (const required of ["LICENSE", "README.md", "README.ja.md", "moon.mod",
  "runtime/array/range.mbt", "runtime/queue/iter.mbt", "strings/strings.mbtp",
  "bitvector/bv32.mbtp", "bitvector/bv8.mbtp", "bitvector/bv16.mbtp",
  "runtime/int32/checked.mbt", "runtime/int64/checked.mbt", "runtime/conversion/conversion.mbt",
  "runtime/bytes/codec.mbt", "encoding/encoding.mbtp", "algebra/algebra.mbtp",
  "graph/graph.mbtp", "runtime/graph/graph.mbt"]) {
  assert.ok(entries.includes(required), `Missing packaged file: ${required}`);
}
for (const entry of entries) {
  assert.ok(!/^(?:_build\/|examples\/|benchmarks\/|checks\/|tools\/|\.git\/|moon\.work$|TODO\.md$)/.test(entry),
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
    let copy = @graph.Graph::from_iter(graph.iter(), vertex_count=2)
    assert_eq(copy.to_array(), graph.to_array())
  }
`);
  process.stdout.write(run("moon", ["test", "toolkit", "--target", "js", "--deny-warn"], consumer));
  process.stdout.write(run("moon", ["test", ".", "--target", "js", "--deny-warn"], consumer));
  process.stdout.write(run("moon", ["prove", ".", "--deny-warn"], consumer));
  console.log(`Packaged ${entries.length} files; both README quickstarts execute and prove.`);
} finally {
  rmSync(directory, {recursive: true, force: true});
}
