# Verification and property tests

[日本語](verification.ja.md) | [README](../README.md)

## Verify the repository

Requirements: MoonBit, the bundled Why3 data at `~/.moon/share/why3/`, Z3 on PATH, Node.js 24+, just, and unzip. The Node scripts have no npm dependencies.

`just setup-solvers` downloads [CVC5 1.3.4](https://github.com/cvc5/cvc5/releases/tag/cvc5-1.3.4) into `_build/solvers/` and verifies the pinned official SHA-256 digest before extraction. It supports macOS and Linux on arm64/x64, preserves the distribution's licenses, and reuses the local installation. To use an existing executable, set `VERI_CVC5=/path/to/cvc5`; no download is then needed. Proof recipes and `just verify` run this setup automatically.

```sh
just setup-solvers # Install the additional prover locally (network needed once)
just doctor        # Check versions and bundled Why3 data
just verify        # Run proofs, negative controls, reference checks, and backend tests
```

To run individual checks:

```sh
just prove         # Prove both workspace modules: MoonBit → Why3 → SMT
just prove-machine # Prove bounds, runtime bridges, and their example with machine integers
just prove-collections-machine # Prove collection implementations and clients with machine integers
just prove-foundations-machine # Prove order, arithmetic, real and IEEE error contracts with machine integers
just core-capabilities # Probe direct calls to core from contracted functions
just conversion-capabilities # Probe native numeric casts and UInt16 support
just array-capabilities # Report old-state/snapshot support and mutable-alias rejection
just smt           # UNSAT proofs and SAT witnesses for FP, bitvectors, arrays, and strings
just negative      # Check that deliberately false claims in each model are not proved
just negative bitvector runtime/uint32 runtime/uint64 # Select affected negative controls
just test js       # Run runtime checks
just quickcheck js # Run only the QuickCheck properties
just bench native # Compare collections with core; save timings and ratios
just bench-backends # Run the comparisons sequentially on all four backends
just bench-check native 1.0 # Fail unless both measurement orders meet the ratio limit
just test-backends # JS / wasm / wasm-gc / native
just test-release  # Run the same checks in optimized builds
just fp-capabilities # Report native Float/Double proof-lowering support
just vectors       # Regenerate expected results from Z3
just vectors-check # Compare checked-in reference values with the current Z3 results
just fmt           # Format sources and generate public interfaces
just package-check # Execute and prove both README quickstarts from the package ZIP
```

The locally verified environment uses moon 0.1.20260904, moonc v0.10.12+1634b282e, Z3 4.16.0, and CVC5 1.3.4.
In this toolchain, `moon prove` automatically uses `~/.moon/share/why3`. No separate Why3 installation is needed.
The `just` proof recipes generate `_build/why3/why3.conf` with Z3 and CVC5 encodings for bitvectors, quantified laws and real-valued IEEE models.
Proof results appear in `*.proof.json` files under each module’s `_build/verif/` directory.
Use `just prove`: bare `moon prove` uses only the default encoding and can time out on integer/BV bridge goals.

These commands run from a checkout of this repository. To reuse its generated
solver configuration in another project, first run `just prover-config` here,
then run `moon prove --why3-config /path/to/veri/_build/why3/why3.conf` in that
project. The config refers to local files, so keep that checkout available.
The package ZIP excludes the development workspace, examples, benchmarks, and
tools; `just package-check` verifies its contents and the consumer quickstart.

## QuickCheck properties

Properties under `bounds/` and `runtime/` use `moonbitlang/core/quickcheck`
with fixed seeds in `20260914`–`20260927`. Most run 1,000 accepted cases;
graph comparisons run 500 small-weight graphs, 500 boundary-weight graphs and 200
edit traces, checking all source/target pairs against Floyd–Warshall. Generated sizes
grow up to 64, or 128 for collection traces and red-black balance. Graphs have up to
7 vertices and 48 generated input edges. Another 500 cases check vertex relabeling
and edge reordering, and 500 corrupted-certificate cases add one guaranteed reachable
edge before tampering with distances, reachability and parents.
The independent oracle uses `Int64?`, distinguishing unreachability from finite
distances above Int max. Returned paths are checked against the original edge array
without using the runtime graph's edge lookup or certificate checker. Standard
tuple/array shrinking reduces each original input before replay. Additional APIs
check 500 cases each for Map/Set collision traces, binary search, Union-Find,
topological witnesses, and two parser-composition properties, plus 1,000 edge-relaxation cases.
A further 1,000 raw-certificate cases mutate arbitrary labels and parents, checking
a valid certificate in every sample as a nonvacuity control (seed `20260926`).
Topology checkers also compare 1,000 arbitrary witnesses against independent
references, checking a valid known-DAG or forced-cycle certificate in every sample
(seed `20260927`), using standard tuple/array shrinkers. They run
with `just quickcheck js` (or `wasm`, `wasm-gc`, `native`) and are also included
in `just test`, `just test-backends`, `just test-release`, and `just verify`.

The properties cover clamp bounds and monotonicity; wrapping integer arithmetic
and order; array reads before and after writes; the SMT Unicode alphabet and
scalar indexing; FP bit encodings, classification, sign operations, arithmetic
identities, and precision roundtrips. Text operations are compared with a
separate scalar-iteration reference. FP inputs come from arbitrary `UInt` /
`UInt64` encodings so exceptional values and the full exponent range are
reachable. Non-NaN comparisons retain the sign of zero; NaNs are compared by
classification, without requiring payload preservation.

Collection properties compare lists, stack/queue operation traces, priority queues,
tree traversals, and BST insertion/search against independent array models.
The minimum priority queue is also compared with MoonBit core's priority queue
using `Reverse[Int]`, since the core queue returns the maximum by default.
Each trace checks that earlier persistent values retain their contents.

For example, with `mizchi/veri/runtime/uint32` and
`moonbitlang/core/quickcheck` imported `for "test"`:

```moonbit
test "quickcheck: wrapping roundtrip" {
  @quickcheck.check(
    (input : (UInt, UInt)) => {
      let (value, delta) = input
      @uint32.sub(@uint32.add(value, delta), delta) == value
    },
    count=1000,
    seed=20260914,
  )
}
```

QuickCheck reports a shrunk counterexample on failure. Rerun the same property
with its seed to reproduce it; change the seed to explore another deterministic
sample. These are sampled runtime properties, alongside the Z3 reference cases
and formal proofs. They do not establish universal IEEE conformance.

`testing/commands` implements `moonbitlang/core/quickcheck/shrink.Shrink` for
`Push(Int) | Pop | Peek | Clear`. Core's array shrinker removes chunks of the
operation trace, and the command shrinker reduces `Push` values using the core
Int shrinker. The binary-tree generator has a recursive shrinker that replaces
nodes with subtrees and shrinks values throughout the tree. These checks set
`max_shrinks=1000`; this bounds the search and does not guarantee a globally
minimal counterexample for every property.

A separate regression test uses `@quickcheck.report` on the deliberately false
claim that all pushed values are less than 3, then checks that the report contains
`counterexample=[Push(3)]`. This is an intentionally false `quickcheck:*` test and verifies the
failure/shrinking path; it is not counted as a successful 1,000-case property.
A graph regression similarly shrinks the false law “minimum edge count equals
minimum weight” to one edge of weight zero (`counterexample=[0]`).
