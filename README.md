# veri

English | [日本語](README.ja.md)

A small foundation for formal verification in MoonBit, with reusable logical models and lemmas, implementations with contracts, and runtime differential checks.

Proof bindings cover finite sets, sequences, lists, bags, finite maps, binary trees, fixed-size bitvectors, total arrays, strings, and IEEE floating point. For IEEE 754, the repository checks **binary32 and binary64 / roundTiesToEven (RNE)** execution results and proves properties in Why3's IEEE models. It does not certify full compliance with the standard or prove the correctness of the MoonBit compiler or CPU.

## Use as a dependency

To use a published release, add it to your own project:

```sh
moon add mizchi/veri
```

Add the import and proof setting to the consuming package's `moon.pkg`:

```moonbit
import {
  "mizchi/veri/bounds",
}

options("proof-enabled": true)
```

Put this code in `digit.mbt`. Like core `Int::clamp`, `clamp` includes both bounds.
Use `clamp_half_open(value, lower, upper)` for an exclusive upper bound.
Both functions require valid bounds; their proof preconditions are not runtime checks.

```moonbit
pub fn digit(value : Int) -> Int where {
  proof_ensure: result => 0 <= result && result <= 9,
} {
  @bounds.clamp(value, 0, 9)
}

test "clamp includes its upper bound" {
  assert_eq(digit(10), 9)
}
```

```sh
moon test --target js
moon prove
```

This minimal proof uses bundled Why3 and Z3 on PATH. Runtime API use alone does
not require a solver, Node.js, or just. Logical types, `model`, lemmas, and
predicates are proof-only and cannot be called in ordinary runtime code.
For complex BV/real proofs that need additional solver configuration, see the
repository verification instructions below.

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

## Structure and guarantees

| Path | Contents | What is checked |
| --- | --- | --- |
| `bounds` | Inclusive clamp and explicit half-open clamp | Given valid bounds, the result lies within the interval and preserves inputs already in range |
| `fset` | Bindings to Why3's finite-set model | Lemmas for empty sets, insertion, and union |
| `seq` / `list` | Finite sequence and inductive list models | Concatenation, lengths, reversal, indexing; `list/conversions` connects the models |
| `bag` / `fmap` | Multisets and finite maps | Multiplicity, union, lookup after update, domain and removal |
| `bintree` | Logical binary trees | Size, height, membership, and traversal length |
| `runtime/list` / `runtime/stack` / `runtime/queue` | Persistent lists, LIFO stacks, and FIFO queues | Structural list correspondence and operation contracts |
| `runtime/pqueue` | Persistent Int minimum priority queue | Sortedness, minimum removal, and exact multiplicities |
| `runtime/bintree` / `runtime/bintree/search` | Binary trees and Int search trees | Inorder correspondence; insertion preserves strict BST order and membership |
| `examples/collections` | Collection clients in the example module | Composed LIFO, FIFO, minimum, and search contracts |
| `testing/commands` | QuickCheck operation generators and shrinkers | Replayable traces; a deliberate failure shrinks to `[Push(3)]` |
| `ieee754` / `ieee754/float32` | Logical binary64 / binary32 values and shared rounding modes | Lemmas about NaN, signed zero, and self-subtraction of finite values |
| `ieee754/conversions` | Logical widening and narrowing | Binary32 widening roundtrip and preservation of NaN classification |
| `bitvector` | Why3 fixed-size bitvector bindings | Operations and modular integer conversions |
| `bitvector/laws` | Bitvector lemmas, with integer laws in `laws/integers` | Bitwise laws, conversions in both directions, and unsigned value bounds |
| `arrays` | Total maps with select/store | Read after write, unchanged other keys, and last-write-wins |
| `strings` | Logical SMT strings | Concatenation, length, substring, search, and replacement |
| `examples/models` | Examples importing the libraries | Cross-module proofs, including arrays with bitvector keys and string values |
| `integer` | Unbounded integers and runtime value projections | Shared contract vocabulary for Int / UInt / Int64 / UInt64 |
| `runtime/uint32` / `runtime/uint64` | Wrapping add/sub implementations | Direct BV contracts for add/sub/less under both integer preludes; Z3 differential checks |
| `runtime/array` | FixedArray reads, writes, swaps, fills and range copies | Safe bounds and operation contracts; full before/after correspondence is checked by QuickCheck |
| `arrays/range` | Mathematical range and before/after models | Frame preservation, swap, fill and copy lemmas |
| `runtime/text` | Validated SMT-compatible text | Code point length, char_at, and substring checked against Z3 |
| `examples/bridges` | Runtime bridge clients | Contracts compose across module boundaries |
| `runtime/float32` / `runtime/float64` | Runtime FP APIs and exact reference comparisons | Arithmetic, sqrt, neg/abs, comparisons, classification, and non-NaN bit roundtrips |
| `runtime/float_conversions` | Precision conversion checks | Float ↔ Double compared against Z3, including rounding boundaries |
| `examples/floating` | Runtime FP usage | Different rounding precision in Float and Double |
| `runtime/int32` / `runtime/int64` | Checked signed add/sub/mul | Exact mathematical results or overflow rejection, proved under both integer preludes; BigInt comparisons |
| `runtime/conversion` | 9 checked conversions and 3 unconditional widenings across signedness and widths | Representability checks proved; native cast results compared with BigInt |
| `encoding` / `encoding/bitvector` | Positional LE/BE byte models | Roundtrips, byte bounds and lengths for 8/16/32/64 bits, plus BV correspondence |
| `runtime/bytes` | Byte / UInt16 / UInt / UInt64 codecs over BytesView | Proved read bounds and consumed length; native codecs differential-tested |
| `algebra` | Explicit operation laws and map/fold models | Identity/composition, ordered splits, monoid partitions and commutative reordering |
| `graph` | Paths, reachability, weights and finite-set certificates | Composition/decomposition, closed sets, feasible-label shortest-path and BFS certificates |
| `runtime/graph` | Immutable directed graphs, BFS and Dijkstra | Independent distance model, executable certificate checks, graph/trace shrinking |
| `examples/toolkit` | Checked allocation, binary headers, aggregation and routes | Cross-module contracts and runtime clients |
| `checks/` | SMT-LIB 2 checks for FP, bitvectors, arrays, and strings | Properties over all inputs and counterexamples with fixed inputs |
| `checks/negative` | Deliberately false lemmas | False claims must not be reported as successfully proved |

The root is the `mizchi/veri` library module. `examples/` is a separate
`mizchi/veri-examples` module that depends on it. `moon.work` registers both:

```text
veri/
├── moon.mod                 # mizchi/veri
├── moon.work                # members: ".", "examples"
├── bounds/
├── bitvector/
├── encoding/
├── algebra/
├── graph/
├── arrays/
├── strings/
├── fset/
├── seq/
├── list/                    # laws, indexed, conversions
├── bag/
├── fmap/
├── bintree/
├── ieee754/
├── integer/
├── runtime/                 # numeric/text bridges and collection implementations
├── testing/commands/
└── examples/
    ├── moon.mod             # mizchi/veri-examples; imports mizchi/veri@0.1.0
    ├── models/
    ├── bridges/
    ├── floating/
    ├── collections/
    └── toolkit/
```

Workspace resolution uses the local library without downloading it from the registry.
Public package imports use paths such as `mizchi/veri/bounds`, `mizchi/veri/bitvector`, and `mizchi/veri/arrays`.
Run `just prove` to prove the library and examples. In this toolchain, `moon prove`
on its own selects the current module; `moon -C examples prove` proves the examples.
Proof reports are written under each module's `_build/verif/` directory.

`.mbt` files contain implementations, types, and contracts; `.mbtp` files contain logical models and lemmas.
Public APIs are listed in `pkg.generated.mbti`.
The abstract types in `fset`, `seq`, `list`, `bag`, `fmap`, `bintree`, `ieee754`, `ieee754/float32`, `bitvector`, `arrays`, and `strings` are **proof-only**. Runtime correspondence is provided separately by implementations under `runtime/` where stated.

A minimal example:

```moonbit
// Import mizchi/veri/ieee754 and enable proof-enabled in moon.pkg.
// Place the following in a .mbtp file.
lemma adding_nan_is_nan(x : @ieee754.Float64, y : @ieee754.Float64) where {
  proof_require: @ieee754.is_nan(x),
  proof_ensure: @ieee754.is_nan(
    @ieee754.add(@ieee754.nearest_even(), x, y),
  ),
} {}
```

At runtime, use `@float64.matches(actual, Bits(expected_bits))` for exact bit matching,
or `@float64.matches(actual, AnyNaN)` to check NaN classification.
An incorrect zero sign or a difference of even 1 ULP in a finite value fails the bit comparison.

## Bitvector API

Import `"mizchi/veri/bitvector"` in `moon.pkg` for all four widths. Bring the types into scope in a `.mbt` file:

```moonbit
using @bitvector {type Bv8, type Bv16, type Bv32, type Bv64}
```

Proofs in `.mbtp` and runtime contracts then use `Bv32::add(x, y)`, `Bv64::add(x, y)`, `Bv32::of_integer(n)`, and the corresponding type methods. The types retain their distinct Why3 `bv.BV8` / `bv.BV16` / `bv.BV32` / `bv.BV64` representations. The current `.mbtp` parser requires the `using` form for imported type methods. This replaces the previous per-width package imports and free functions.

Public lemmas have width suffixes, such as `@laws.addition_wraps32()` / `addition_wraps64()` in `bitvector/laws` and `integer_roundtrip32` / `integer_roundtrip64` in `bitvector/laws/integers`. Keeping integer conversion laws separate limits quantified proof context. `examples/bitvector/widths.mbtp` proves that the value 2^32 wraps in Bv32 but is preserved in Bv64 using a single package import. `just prove-machine` also checks these laws and the example with machine integers.

## Checked arithmetic, codecs, algebra and graphs

`runtime/int32` and `runtime/int64` provide `checked_add`, `checked_sub` and
`checked_mul`. `Some(value)` is the exact mathematical result; `None` means the
result is outside the destination range. Both integer preludes prove these
contracts, including intermediate-operation safety in the machine prelude.
`runtime/conversion` provides all 12 directed conversions among `Int`, `UInt`,
`Int64` and `UInt64`. The nine fallible conversions use `checked_`, such as
`checked_int_to_uint` and `checked_int64_to_int`, and return `Option`.
The three unconditional widenings (`int_to_int64`, `uint_to_int64`,
`uint_to_uint64`) return their native destination values directly, using core's
casts. `can_*` proves the exact range decision; `converted_*` specifies value
preservation (wrap a widening result in `Some` in that specification).
These functions take native types; MoonBit does not allow this package to add
public methods directly to builtin numeric types. Native casts are currently rejected
by the proof frontend, so their correspondence is tested with independent
`BigInt` arithmetic rather than assumed. `just conversion-capabilities` records
this boundary, including unsupported UInt16 lowering.

`runtime/bytes` uses MoonBit type names: `byte_to_bytes` and
`{uint16,uint,uint64}_to_{le,be}_bytes`, following core's `to_le_bytes` /
`to_be_bytes` convention. `read_byte` and `read_{uint16,uint,uint64}_{le,be}`
take `(data : BytesView, offset : Int)` and return the native value as `T?`.
For sequential parsing, `decode_byte` and `decode_{uint16,uint,uint64}_{le,be}`
return `Decoded[T]?`, with `value` and `next_offset` relative to the view. Negative,
overflowing and truncated offsets return `None`; trailing bytes are permitted.
`read_end` proves the bounds check and exact consumed length. `encoding` proves
LE/BE roundtrips, octet ranges and lengths; `encoding/bitvector` connects these to
Bv8/Bv16/Bv32/Bv64, and `runtime/bytes.byte_model` connects native Byte to Bv8.
Native codec values, UInt16 casts and view-offset handling are differential-tested;
the codec bodies have no universal value-correspondence proof. UInt16 uses its
natural MoonBit runtime type. Encoders return fresh immutable `Bytes`.

`algebra` defines `associative`, `identity`, `commutative` and `monoid` over a
supplied pure operation, and structural models over `runtime/list.List`.
`fold_split` needs no algebraic assumptions; `fold_partitions` and
`fold_directions` require a monoid; `reorder_partitions` also requires
commutativity. `map_identity` and `map_composition` are proved by induction.
Runtime `List::map(f)` and `List::fold(init=initial, f)` match core/list's
`raise?` callbacks: they run left to right and propagate an error immediately.
`List::from_iter` consumes a core `Iter` in order. Core differential tests,
shrinking, law, callback error and long-list tests cover these APIs. Effects in runtime callbacks are
outside the pure model. No law is assumed for an arbitrary operation.

`runtime/graph.Graph::from_array(edges, vertex_count=n)` validates a directed graph over
`0..<vertex_count` with nonnegative Int weights, self-loops and parallel edges.
It copies input edges. `Graph::new(vertex_count=n)` creates vertices without edges;
`from_iter(edges, vertex_count=n)` consumes a core `Iter`. `iter()` / `to_array()`
traverse edges in source-vertex order, preserving input order within each source.
Constructors and searches return values directly and `raise GraphError`, so they
compose with MoonBit's `try ... catch`. `bfs(source)` minimizes edge count; `dijkstra(source)`
minimizes weight using the existing FIFO and minimum-priority queues. Results
provide `distance(vertex)` and a fresh `path_to(vertex)` including both endpoints.
Invalid or unreachable lookup vertices return `None`; invalid sources return an
error. Dijkstra rejects a reachable shortest distance beyond Int max, while an
overflowing detour does not reject a representable alternative.
`check_bfs` / `check_dijkstra` independently validate paths, edge inequalities and
closure of the reachable set. These diagnostic checks take O(V(V+E)) time in the worst case because they
reconstruct paths and scan adjacency lists; algorithms do not run them implicitly.

`graph` proves path concatenation/decomposition, weight additivity, closure in
`fset`, and shortest-path certificates from feasible distance labels. Its logical
path stores successors (source omitted, target included); runtime `path_to`
includes the source. BFS and Dijkstra implementations and executable certificate
checkers are tested against an independent Floyd–Warshall model, including zero
cycles, disconnected vertices and overflow. Their complete mutable algorithm
bodies are not formally proved. `examples/toolkit` shows the runtime APIs and
composes arithmetic, aggregation and finite-set proof contracts.

## Orders, number theory, reals, and error bounds

| Package | Contents |
| --- | --- |
| `relations` | Equivalence, preorders, partial/total orders, reverse and lexicographic order, with explicit laws for the supplied relation |
| `seq/order` | Sortedness, sorted permutations, subrange permutations, exchanges and swap laws, using mathematical indices |
| `integer` / `integer/laws` | Arithmetic, absolute value, min/max, Euclidean and truncating division, and their remainder correspondence |
| `integer/aggregate` / `integer/aggregate/laws` | Nonnegative integer powers, half-open interval sums and their decomposition |
| `number` / `number/laws` / `number/parity` | Divisibility, GCD, coprimality, parity and laws |
| `runtime/number` | UInt GCD, safe Int quotient/remainder and Euclidean remainder for a positive modulus |
| `real` / `real/laws` | Proof-only mathematical reals, integer embedding, floor/ceil, distance and error composition |
| `ieee754/error` / `ieee754/error/operations` | Real projections, rounding, binary32/64 operation bounds and input-error propagation |
| `examples/foundations` | Cross-module examples composing order, GCD, real and rounding contracts |

`relations` expresses the laws from [Why3 relations](https://why3.org/stdlib/relations.html) as predicates over a supplied `(T, T) -> Bool` relation. No arbitrary comparator is assumed to define a total order. Lexicographic transitivity requires laws for both component orders. `seq/order.sorted_permutation` specifies sortedness and preservation of multiplicities; it does not implement a sorting algorithm. Exchange and permutation bindings use [Why3 seq](https://why3.org/stdlib/seq.html).

Division conventions are explicit: `integer.div(-7, 3) = -3` and `integer.modulo(-7, 3) = 2`, whereas `integer.trunc_div(-7, 3) = -2` and `integer.trunc_mod(-7, 3) = -1`. Logical division/remainder laws require a nonzero divisor. `runtime/number.div_rem` returns `None` for division by zero and `Int::min_value / -1`. `euclidean_mod` returns `Some(r)` only for a positive modulus and guarantees `0 <= r < modulus`. [Why3 int](https://why3.org/stdlib/int.html)

`runtime/number.gcd` uses Euclid's algorithm. Its correspondence to [Why3 number.Gcd](https://why3.org/stdlib/number.html) and termination are proved across the UInt range, with `gcd(0, 0) = 0`. Division, remainder and GCD are checked under both integer preludes. Runtime tests compare GCD with independent divisor enumeration and reconstruct signed division in Int64, checking signs and boundaries. QuickCheck uses the standard tuple shrinker.

`real.Real` is an exact specification type, not a runtime conversion from Double. Division laws require a nonzero denominator. `real.within(actual, ideal, tolerance)` means `|actual - ideal| <= tolerance`; a negative tolerance cannot satisfy it. Laws cover addition with input errors, the triangle inequality and integer embedding. [Why3 real](https://why3.org/stdlib/real.html)

For an ideal real result `z`, RNE rounding without overflow has these error bounds:

- binary32: `2^-24 * |z| + 2^-150`
- binary64: `2^-53 * |z| + 2^-1075`

These use `round_bound_ne` from [Why3 ieee_float](https://why3.org/stdlib/ieee_float.html). Constants are constructed as exact proof-level reals; the absolute term covers subnormal rounding. `ieee754/error/operations` bounds addition, subtraction, multiplication and division with finite-input and `no_overflow` premises, plus a nonzero divisor for division. Addition also composes input errors `ex + ey` with the new rounding error. The native SMT floating-point witnesses in `checks/*/half-subnormal-error.smt2` show why a relative-only bound is insufficient.

These are proofs about the Why3 IEEE model. They introduce no assumed correspondence between runtime Float/Double and real projections. Runtime coverage remains the existing Z3 reference comparisons and the support reported by `fp-capabilities`.

Besides native SMT and the BV arithmetic encoding, `just prover-config` generates Z3/CVC5 routes retaining Why3's float axioms and rounding-error lemmas, and a Z3 route encoding definitions as equivalent axioms to support quantified-law matching. CVC5 complements Z3 for quantified sequence laws and nonlinear real error bounds. Bundled Why3 files remain untouched; no custom assumptions or `proof_axiomatized` annotations are added. Use `just prove` normally and `just prove-foundations-machine` for checked machine integers. `just verify` includes both and the negative controls.

## Runtime collection API

Own types provide methods: `List::new()`, `Stack::new()`, `Queue::new()`,
`IntMinQueue::new()`, `IntSet::new()`, and `Tree::new()`. Updates return new
persistent values; existing versions remain usable. `IntMinQueue` is explicitly
an Int-only minimum queue with duplicates; `IntSet` stores unique Int keys.
The existing free functions remain aliases of the same contracted implementations.

```moonbit
// Import "mizchi/veri/runtime/queue".
test "persistent queue and Iter" {
  let original : @queue.Queue[Int] = @queue.Queue::new()
  let queue = original.push(1).push(2)
  assert_true(original.is_empty())
  assert_eq(queue.iter().map(x => x * 2).to_array(), [2, 4])
}
```

`iter()` creates independent consuming traversal state without first converting
the collection to an array: list order, stack top first, queue FIFO order,
ascending minimum-queue/set order, and inorder for trees. Iteration and array
conversions are runtime-tested; their correspondence has no proof contract.
List methods follow core naming: `prepend`, `concat`, and `rev`; the free aliases
`cons(value, list)`, `append(left, right)`, and `reverse(list)` remain available.

## FixedArray updates and ranges

`runtime/array` directly updates built-in `FixedArray[T]` values. Ranges are
specified by `Range { start, count }`, meaning `[start, start + count)`. Every update
returns `true` on success and `false` for invalid indices or ranges. Invalid
operations leave the array unchanged; an empty range at the end is valid.
`Range` is a small `#valtype` record. Its named fields prevent confusing offsets
and counts, while positional function calls remain usable in verified code.
The current frontend rejects labelled calls in contracted bodies. A `Range`
can contain invalid values; constructing it does not assert any bounds.

| API | Behavior |
| --- | --- |
| `valid_range(length, range)` | Validate endpoints without overflowing, including for extreme invalid inputs |
| `set(array, index, value)` | Write one cell |
| `swap(array, left, right)` | Exchange two cells; equal indices are valid |
| `fill(array, value, range)` | Fill a range |
| `blit(source, target, source_range, target_start)` | Copy between arrays, allowing overlapping source and destination |
| `blit_disjoint(source, target, source_range, target_start)` | Verified copy between **distinct arrays** |
| `copy_within(array, source_range, target_start)` | Copy within one array, including overlapping ranges, using the original source values |

`set` and `swap` take constant time; range updates take O(count) time and constant
auxiliary space. `copy_within` copies backwards when moving towards higher
indices, without allocating a temporary array. This states algorithmic costs,
not measured performance parity with core. `blit` checks object identity and
selects `copy_within` for the same array or `blit_disjoint` for distinct arrays.
The dispatcher is runtime-tested and has no proof contract. Verified callers
choose `copy_within` or `blit_disjoint`; Why3 rejects passing aliases to the latter.
`range_in_bounds(length, start, count)` is a **proof-only** predicate over
mathematical endpoints. Use `valid_range(length, range)` at runtime.

```moonbit
// Import "mizchi/veri/runtime/array".
test "range updates" {
  let xs : FixedArray[Int] = [0, 1, 2, 3]
  assert_true(@array.fill(xs, 9, { start: 1, count: 2 }))
  assert_true(@array.copy_within(xs, { start: 0, count: 3 }, 1))
  assert_eq(xs, [0, 0, 9, 9])
}
```

The runtime proofs cover range validation, safe indexing, arithmetic bounds and
loop termination under both integer preludes. They also establish the value
written by `set`, the exchanged values through local assertions in `swap`, the
whole filled range, and equality of copied cells with the distinct source in
`blit_disjoint`. The public `swap` and `copy_within` contracts expose success/bounds only.
`examples/bridges.fill_and_read` proves that a caller can compose `fill` and `get`.

`arrays/range` defines full before/after specifications: `unchanged_outside`,
`filled`, `copied`, and `exchange`. Its seven proved lemmas cover single writes,
swap/undo, empty operations, and extending a fill or copy by one cell. The models
use mathematical indices and [Why3 map](https://why3.org/stdlib/map.html)
range equality/exchange. `copied` always reads the **pre-state** source, including
for overlap. These lemmas do not establish full runtime correspondence.

The current compiler has no usable `old(...)` contract expression, and
`proof_let` snapshots cause a compiler assertion failure. Consequently, complete
before/after correspondence, preservation outside the written range, unchanged
state on failure, and overlap copying are checked against snapshot references
with QuickCheck; they are **not universally proved for the runtime functions**.
The eight array-update properties run 1,000 cases each, including operation traces,
full-width indices and nearby valid ranges, with core tuple/array shrinkers.
A deliberately incorrect forward copy is falsified and shrunk to a three-cell
overlap. Negative proof controls reject wrong filled values, overflowing ranges,
out-of-range writes in the model, and copying from an already modified source.

`just array-capabilities` records the compiler limitations and checks alias
rejection in `_build/array-capabilities.json`; it is included in `just verify`.
Predicates wrapping array reads in local proof annotations also avoid the
compiler treating mutating functions as Why3 ghost code. No new assumed
contracts or custom axioms are introduced. Implementation status and proof boundaries are recorded in [TODO.md](TODO.md) in the repository.

## QuickCheck properties

Properties under `bounds/` and `runtime/` use `moonbitlang/core/quickcheck`
with fixed seeds `20260914` and `20260915`. Most run 1,000 accepted cases;
graph comparisons run 500 graphs and 200 edit traces, checking all source/target
pairs against Floyd–Warshall. Generated sizes grow up to 64, or 128 for collection
traces and red-black balance. Graphs have up to 7 vertices and 48 input edges. They run
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

## Collection benchmarks

`benchmarks/collections` uses [MoonBit's benchmark API](https://docs.moonbitlang.com/en/latest/language/benchmarks.html)
through `moon bench --release --no-parallelize`. It measures 14 workloads at
256 and 2,048 elements, producing 34 comparisons per backend. Two direct tree
`to_array()` workloads supplement the unchanged `inorder().to_array()` workloads. Each implementation
runs in two opposite orders with five calibrated batches per pass. Results are
kept with `Bench.keep`, and exact output equality is checked before timing on
the same optimized backend. Empty inputs and repeated calls are also tested.

| Workload | Core comparison | Timed work |
| --- | --- | --- |
| List | `core/list` | Reverse/append followed by array conversion; length |
| Stack | `core/list`, built-in `Array` | Push all elements, then drain into a fresh array |
| Queue | `core/queue` | Push and drain; repeated peek on a prebuilt queue |
| Minimum priority queue | `core/immut/priority_queue`, `core/priority_queue`, both using `Reverse[Int]` | Push and drain, including duplicates, shuffled and ascending inputs |
| BST | `core/immut/sorted_set` | Insert, then query every key and equally many missing keys, with shuffled and ascending insertion |
| Binary-tree traversal | `core/immut/sorted_set` | Materialize the same contents from balanced and left-skewed trees, measuring linked-list intermediates and direct arrays separately |

The generic binary tree has no direct core counterpart here; its comparator
performs ordered enumeration, not arbitrary-shape tree manipulation. Mutable
baselines are used with one current state and no retained snapshots; no copying
is charged to simulate persistence. Input generation and read-only fixture
construction are outside timing; build/drain and build/find workloads include
their own fresh construction and output work. Repeated peek uses the same queue
without popping; the updated queue normalizes on mutation and avoids repeated reversal. A compiler may
hoist repeated reads; these are timings of the optimized workload, not isolated
function-call latency.

`just bench native` (or `js`, `wasm`, `wasm-gc`) saves raw output, JSON summaries,
and a Markdown comparison under `_build/benchmarks/collections-<target>.*`.
The report records toolchain, CPU, OS, repository revision, and a fingerprint of
the installed core sources, plus separate SHA-256 hashes of runtime and benchmark sources. Times are the mean of the two batch medians in
microseconds; the ratio is **veri/core**, so values above 1 mean slower. The
paired ratio range describes order variation and is not a confidence interval.
Missing results, invalid timings, and failed benchmark processes fail reporting.

`just bench-check native 1.0` performs a fresh measurement and exits nonzero if
any comparison exceeds the supplied limit in either order. Results straddling
the limit are inconclusive and also fail this check. Benchmarks are separate
from `just verify`, since timing depends on hardware and system load.

The [latest tuning measurements](benchmarks/collections/TUNING.md) show that the
current implementations **do not meet a universal no-slowdown target**. These
comparisons include representation, allocation, and algorithm differences; they
do not isolate proof-contract overhead. Proof-only `seq/list/bag/fmap/bintree`
bindings have no runtime operations to benchmark. Rerun on your deployment
backend and workload before relying on a performance comparison.
The [2026-09-14 measurements](benchmarks/collections/RESULTS.md) remain available
as a historical snapshot of the previous skew-heap implementation.

## Collection models and implementations

| Logical package | Bundled Why3 theories | Interpretation |
| --- | --- | --- |
| `seq` | `seq.Seq`, `Reverse`, `Mem`, `Occ`, `Permut` | Finite sequences with mathematical lengths and indices |
| `list` / `list/indexed` | `list.List`, `Length`, `Append`, `Reverse`, `NthNoOpt`, `NumOcc` | Inductive lists, with optional indexing/counting imports |
| `list/conversions` | `seq.OfList`, `seq.ToList` | Conversion between logical lists and sequences |
| `bag` | `bag.Bag` | Multisets; union adds counts and difference truncates at zero |
| `fmap` | `fmap.Fmap` | Finite maps with a finite-set domain |
| `bintree` | `bintree.Tree`, `Size`, `Height`, `Occ`, `Inorder`, `Preorder` | Binary trees and their content/traversal models |

Logical lengths, counts, and indices use unbounded `integer.Integer`.
Use `seq.get/update` with `0 <= index < length`, and `slice(start, stop)` with
`0 <= start <= stop <= length`; `stop` is exclusive. Logical list `head/tail`
require a nonempty list, and `list/indexed.get(index, xs)` needs an in-range
index. `fmap.find` is meaningful only when `mem(key, map)` holds. These logical
operations do not perform runtime bounds checks; values outside their specified
domains are unspecified.

**`runtime/*` contains independent contracted implementations, not aliases of core.**
The packages implement persistent data structures. Recursive models
connect their actual constructors to Why3 lists, bags, and trees. The stack and
queue APIs follow Why3's LIFO/FIFO specifications; the priority queue follows
the minimum/multiplicity specification. Why3's abstract mutable `val` APIs are
not imported as executable implementations.

Direct wrappers around core were also tested. With the installed toolchain,
`core/list.length`, `core/queue.peek`, `core/immut/priority_queue.push`, and
`core/immut/sorted_set.contains` fail with `Error 4207` inside contracted bodies.
`just core-capabilities` reproduces this and first checks ordinary type correctness.
[MoonBit verification](https://docs.moonbitlang.com/en/latest/language/verification.html)
restricts calls from contracted bodies. `#proof_import` connects logical operations;
it does not prove the corresponding core implementation. Direct reuse with a
correspondence proof needs proof-callable contracts in core or compiler support.
These contracts have not been replaced with `#proof_axiomatized` assumptions.


| Runtime package | Operations and representation | Cost |
| --- | --- | --- |
| `runtime/list` | `empty/cons/uncons/is_empty/append/reverse/length`; immutable linked spine | Basic operations O(1); append/reverse/length O(n) |
| `runtime/stack` | `empty/push/pop/peek/is_empty`; linked cells also used as pop results | O(1) |
| `runtime/queue` | `empty/push/pop/peek/is_empty`; front list and reversed back list | Push/peek O(1); pop amortized O(1), worst-case O(n) |
| `runtime/pqueue` | `empty/push/pop/peek/is_empty`; Int two-pass pairing heap, duplicates retained | Push/peek O(1); pop O(k) for k root children, worst-case O(n) |
| `runtime/bintree` | `empty/node/inorder/to_array`; generic binary tree | Constructors O(1); traversal O(n) |
| `runtime/bintree/search` | `empty/insert/contains`; Int red-black tree without duplicates | Insert/contains O(log n) |

Costs describe states built through the public APIs and are not formally proved. Queue updates
normalize the front list, so repeated peeks do not repeat reversal. Amortized costs
for the queue apply to a single update history; branching from old
snapshots can repeat work. The priority queue follows the
[pairing heap](https://www.cs.cmu.edu/~sleator/papers/Pairing-Heaps.htm): pair adjacent
children from left to right, then merge the paired roots from right to left.
Both passes are tail recursive, with proofs of termination, contents and ordering.
Pairing and linking construct the resulting cells directly, avoiding temporary roots.
The search tree follows
[Okasaki's insertion algorithm](https://www.cambridge.org/core/journals/journal-of-functional-programming/article/redblack-trees-in-a-functional-setting/62BC5EA75A2C95E3F6EE95AE3DADF0E5).
These differ from core's complete binary heap and size-balanced search tree.

BST `valid(tree)` retains its strict search-order meaning: `empty` establishes it
and `insert` preserves it. Insertion, including rotations, and lookup have proofs
of order, membership preservation, and search results. Red-black invariants
(black root, no red-red edge, equal black heights) are checked by shrinking
QuickCheck properties and long ascending/descending tests. Formal proofs of color
balance and complexity, and deletion, are not implemented.

The search-tree API now uses an opaque `@search.IntSet` with internal colors.
Code passing `@tree.Tree[Int]` directly must instead construct a search tree with
`@search.empty()` and `insert`, enumerate with `@search.to_array(tree)`, and use
`@search.model` in contracts. The generic `runtime/bintree.Tree[T]` remains available
for arbitrary shapes. List length uses tail recursion; tree inorder uses a
continuation list for linear traversal. Its left branch is tail-recursive, while
its right branch and List append still use the call stack.
Direct `Tree::to_array()` uses an explicit stack for deep trees in either direction
and avoids an intermediate linked list. Independent QuickCheck models and
20,000-level trees test this runtime conversion.
Stack/Queue/IntMinQueue/IntSet use `#valtype` wrappers, and small operations
use `#inline` to reduce wrapper allocations. Updates also use `#owned` to avoid
unnecessary reference-count operations without changing the existing content/order
contracts. A Stack cell is already `(value, rest)?`, so pop allocates no extra tuple.
`proof_require`, `proof_ensure`, `proof_assert`, and `.mbtp` specifications
are not runtime checks.

`pop/uncons/peek` return `None` for empty inputs. List `length` requires its
mathematical result to fit in an Int (at most 2,147,483,647), including under
the machine-integer prelude. Array conversion helpers (`from_array/to_array`)
are covered by runtime properties but have no correspondence contracts yet.
Persistence preserves the container's structure; stored values may themselves
be mutable. `examples/collections` demonstrates contract composition across
modules, and `just prove-collections-machine` checks the same collection
implementations and examples using machine integers.

## Binding architecture

The MoonBit API binds to **Why3 theories**. Why3's solver driver then maps supported operations to SMT-LIB 2:

```text
MoonBit contracts / .mbtp → Why3 theories → SMT-LIB 2 → Z3 / CVC5
checks/**/*.smt2 ─────────────────────────→ SMT-LIB 2 → Z3
```

`#proof_external` maps a logical type; `#proof_import` maps a logical operation.
The `.smt2` checks use a separate direct path, without going through MoonBit or Why3.
These are proof APIs, not a runtime Z3 FFI or a general-purpose SMT-LIB 2 expression builder.

| Package | Why3 theory | Main operations |
| --- | --- | --- |
| `bitvector` | `bv.BV8` / `bv.BV16` / `bv.BV32` / `bv.BV64` | `add/sub/mul`, `udiv/urem`, `sdiv/srem`, `bw_and/or/xor/not`, `shl/lshr/ashr`, `ult/ule/slt/sle` |
| `arrays` | `map.Map`, `map.Const` | `select`, `store`, `const_array`, extensional `eq` |
| `strings` | `string.String` | `concat`, `length`, `char_at`, `substring`, `contains`, `prefix_of`, `suffix_of`, `index_of`, `replace`, `to_integer/from_integer`, `lt/le` |

Bitvectors have a fixed width: 8, 16, 32 or 64 bits.
Signedness belongs to the operation, not the bit pattern. Addition, subtraction, and multiplication wrap modulo 2^width.
Shift counts are bitvectors of the same width: counts at least as large as the width do not wrap around.
`Bv32::width()` / `Bv64::width()` return 32 or 64 as `integer.Integer`.
Use `width_bv()` for the bitvector encoding required by shift operations. Unsigned division by zero yields all ones in the SMT model;
this is not a claim about runtime division. Unsigned conversions between the four widths use `to_bv8/to_bv16/to_bv32/to_bv64`: widening preserves the value, narrowing keeps the low bits. Arbitrary widths, bit extraction and sign extension are not exposed yet.
`of_integer` first reduces modulo 2^width, so it is defined for negative and oversized mathematical integers too.
`to_integer` returns the unsigned value, `modulus()` is 2^width, and `in_range` recognizes unsigned values.
The conversion laws prove `to_integer(of_integer(n)) = n mod 2^width` and `of_integer(to_integer(v)) = v`.

`SmtArray[K, V]` is a total map from every key to a value. It has no length, bounds check, or mutation.
`store` returns a new map. It can model memory, but does not by itself verify the bounds or behavior of a runtime array.

`Text` uses the SMT string model, whose alphabet covers U+0000..U+2FFFF.
Length counts code points, so an astral character within that alphabet has length one;
this is not MoonBit's runtime UTF-16 length. `char_at` returns a string, and `substring` takes a start and count.
Invalid positions produce empty strings, unsuccessful searches return -1, and `replace` changes the first occurrence.
`to_integer/from_integer` follow SMT nonnegative decimal conversion semantics; their values, lengths and indices use `integer.Integer` under both proof preludes.
Project runtime indices with `@integer.from_int(index)`; these logical operations are not runtime casts.
There is no implicit conversion between `Text` and MoonBit `String`, and regex bindings are not included yet.

See `examples/models/models.mbtp` for a proof combining `SmtArray[Bv64, Text]` with the bitvector and string bindings.
`just smt` checks the corresponding theory laws and concrete witnesses. The per-model negative proof controls
only establish that the false claims were not proved; the direct SAT checks supply concrete witnesses separately.

## Correspondence with MoonBit runtime types

| Runtime type | Model / adapter | Current guarantee |
| --- | --- | --- |
| `Int`, `UInt`, `Int64`, `UInt64` | `@integer.from_int/from_uint/from_int64/from_uint64` → `Integer` | Proof-only numerical projections from the selected MoonBit prelude |
| `UInt`, `UInt64` | `runtime/uint32`, `runtime/uint64` | `model` encodes the value as Bv32/Bv64; add/sub/less prove direct agreement with BV operations under both integer preludes |
| `Int` / `UInt`, `Int64` / `UInt64` | Their 32-/64-bit encodings | 48 Z3 reference cases for native add/sub/mul, bitwise operations, signed/unsigned order, and valid shifts; also check the wrapping adapters |
| `FixedArray[T]` | `@runtime_array.model(a)` → `SmtArray[Integer, T]`, plus `a.length()` | Reads, range validation and update contracts under both preludes; see the array section for the limits of before/after proofs |
| `String` | `@text.from_string(s)` → `@text.Text?` | Validate UTF-16 and the shared alphabet; 72 Z3 reference cases for length, char_at, substring |
| `Float` / `Double` | binary32 / binary64 encoding | 122 operation cases per format plus 62 precision conversion cases against Z3; native FP operations still lack a universal correspondence proof |

`Integer` is an abstract, unbounded **proof-only** type. It stays mathematical even when runtime `Int`
uses the checked machine prelude. These projections are logical functions, not runtime numeric casts.
The default prelude models even `UInt` as an unbounded integer, so the wrapping contracts explicitly
require `0 <= x,y <= MAX`. All runtime values of the corresponding unsigned type satisfy those bounds.
The machine prelude requires arithmetic to avoid intermediate overflow. The adapters meet that requirement
by branching around overflow. The contracts retain the modulo specifications and additionally prove:

```text
model(add(x, y)) = bv.add(model(x), model(y))
model(sub(x, y)) = bv.sub(model(x), model(y))
less(x, y)       = bv.ult(model(x), model(y))
```

These hold for all unsigned runtime inputs, with explicit range preconditions in the mathematical model.
`model_preserves_value` proves that the logical encoding preserves the unsigned numerical value.
`model` is proof-only; the verified runtime entry points are `add`, `sub`, and `less`.
The proofs concern these adapters and the trusted MoonBit/Why3 translation, not arbitrary native operations.

Native bitwise primitive lowering is not fully supported in this toolchain's proof path.
Their runtime correspondence is checked by differential tests; it is not asserted using `proof_axiomatized`.
Shift references use counts in `[0, width)`. Native overshifts and division by zero are not equated with SMT semantics.
Signed comparisons reinterpret the same bit patterns as `Int` / `Int64` before comparing.

For arrays, only model indices in `[0, a.length())` denote runtime cells. The model is the array's
contents at the current program state, not an immutable snapshot across mutations.
There is no full `Array[T]` (growable array) bridge or general store/frame contract yet.

The text adapter accepts well-formed UTF-16 containing scalar values at most U+2FFFF.
It returns `None` for unpaired surrogates or higher code points, without replacement or normalization.
This is the shared subset with the [SMT-LIB string alphabet](https://smt-lib.org/theories-UnicodeStrings.shtml).
`length`, `char_at`, and `substring(start, count)` count code points, not UTF-16 units or graphemes.
For example, `"A😀é".length()` is 4, while the adapter length is 3 and `char_at(1)` is `"😀"`.
Out-of-range positions or nonpositive counts yield empty text; excessive counts truncate at the end.
`runtime/text.Text` is a runtime wrapper distinct from the proof-only `strings.Text`; no proof coercion
or universal correctness theorem for this adapter is claimed. Search, replacement, and regex adapters remain future work.

```moonbit
// Import mizchi/veri/runtime/uint32 and mizchi/veri/runtime/text.
test {
  assert_eq(@uint32.add(0xffffffffU, 1U), 0U)
  let text = @text.from_string("A😀é").unwrap()
  assert_eq(text.length(), 3)
  assert_eq(text.substring(1, 2).to_string(), "😀é")
}
```

`examples/bridges` demonstrates calling proved runtime functions from another module, including
`sub(add(value, delta), delta) == value` for both widths even when addition wraps.
`just vectors` regenerates both FP and runtime references; `just vectors-check` detects stale results.
`just verify` also checks that overflow and ignored-array-cell mistakes are rejected in the proof path,
and runs runtime tests on JS / wasm / wasm-gc / native in debug and release configurations.

### Proof encodings and package boundaries

`just prover-config` derives an arithmetic driver from the installed Why3 `z3_487.drv` and writes it
under `_build/why3/`. It omits only the native-BV encoding imports, retaining the upstream arithmetic
transformations and BV theory axioms. The installed files remain unchanged, and no new axioms are added.
The generated `MoonBit_Auto` strategy retains both Z3 encodings: native bitvectors for bitwise laws,
and the Why3 arithmetic model for integer/BV correspondence. It also tries the real-valued and quantified-law routes described above. These encodings remain within the trusted Why3 boundary.
The generator rejects unexpected upstream import layouts rather than silently deriving a different driver.
After splitting verification conditions, the strategy also uses Why3's
`compute_in_goal` to reduce concrete datatype constructors in structural models.
Doing this after splitting preserves the recursive hypotheses needed by list proofs.
`just prove` limits concurrent package jobs to two to avoid contention between
short solver time limits as the number of packages grows.

Bindings live in `bitvector`; their public lemmas live in `bitvector/laws`,
with conversion lemmas in `bitvector/laws/integers`.
Import the corresponding law package when calling a lemma. Keeping unrelated lemmas out of a caller's
proof context avoids expensive quantifier instantiation. `just prove` checks every package in both modules.
Negative controls use the same complete strategy and include unbounded conversion identity and subtraction
incorrectly specified as addition, to detect a proof path accepting invalid correspondence claims.

## Scope of IEEE 754 verification

**Runtime checks** compare results against Z3 for **122 cases per format** (82 directed cases and
40 reproducible samples), plus **62 Float ↔ Double conversion cases**. Each operation case checks
both the runtime wrapper and the corresponding native expression. The corpus covers four arithmetic
operations, sqrt, negation, absolute value, IEEE equality/order, and NaN/infinity classification.
It also checks non-NaN encoding roundtrips. Cases include halfway rounding, subnormals, the smallest
normal value, overflow, ±0, ±∞, and NaN. Expected results come from Z3, not host floating-point arithmetic.
These checks do not enumerate all inputs.

| Purpose | Float API | Double API |
| --- | --- | --- |
| Bit representation | `@float32.from_bits(UInt)`, `to_bits(Float)` | `@float64.from_bits(UInt64)`, `to_bits(Double)` |
| Operations | `add/sub/mul/div/sqrt/neg/abs` | Same names |
| Comparisons / classification | `eq/less/is_nan/is_infinite` | Same names |
| Precision conversion | `@float32.to_double(Float)` | `@float64.to_float(Double)` |
| Reference matching | `matches(value, Bits(UInt))` or `AnyNaN` | `matches(value, Bits(UInt64))` or `AnyNaN` |

```moonbit
// Import mizchi/veri/runtime/float32 and mizchi/veri/runtime/float64.
test {
  let one = @float32.from_bits(0x3f800000U)
  let half_ulp = @float32.from_bits(0x33800000U)
  assert_true(@float32.matches(@float32.add(one, half_ulp), Bits(0x3f800000U)))
  let wide = @float32.to_double(one)
  assert_true(@float64.matches(wide, Bits(0x3ff0000000000000UL)))
}
```

The logical API is separate: `ieee754.Float64`, `ieee754/float32.Float32`, and
`ieee754/conversions.widen/narrow`. Both logical formats share `ieee754.RoundingMode`.
The conversion laws prove the binary32 → binary64 → binary32 roundtrip with RNE, including zero's sign
and abstract NaN identity. The reverse roundtrip loses precision for some finite binary64 values;
`checks/fp32/narrowing-loss.smt2` provides a concrete SAT witness. No runtime NaN payload preservation is claimed.

**Formal verification in the model** proves properties for every model value satisfying the stated preconditions.
Examples include “x - x is zero for finite x” and “negating a NaN produces a NaN.”
For properties that do not hold, such as associativity of addition, a concrete counterexample can be given:

```text
a = 2^53, b = -2^53, c = 0.5, rounding mode RNE

(a + b) + c = 0.5
a + (b + c) = 0.0
```

This counterexample is reproduced in both SMT and MoonBit.

**Connecting these models to native Float / Double operations is still blocked by compiler support.**
In the tested toolchain, native FP arithmetic in a contracted function body produces
`unsupported primitive operator in contracted function body`. Comparisons in logic bodies are also unsupported.
`just fp-capabilities` reproduces this in fresh temporary modules and records `_build/fp-capabilities.json`.
It reports compiler capability separately from IEEE correctness: accepting arithmetic lowering in a future
compiler would still require checking the generated IEEE types, rounding rules, and proving the correspondence.
The runtime FP APIs therefore have no proof contracts or assumed `model(Float/Double)` coercion.
The Why3 logical laws and runtime differential tests are both available; a theorem connecting the two remains future work.

## Trusted boundary and limitations

- The type mappings, argument order, and Why3 symbol mappings in `#proof_external` / `#proof_import`, along with Why3, the solver, and MoonBit's translation, are trusted. No custom `proof_axiomatized` declarations are used.
- Default integer proofs use mathematical integers. Bounds, unsigned wrapping adapters, FixedArray reads and updates, collections, strings, and their examples are also proved separately with the bundled machine-integer model. `min <= max` for `clamp` and `lower < upper` for `clamp_half_open` are caller preconditions, not runtime input checks.
- The runtime check profile is binary32 and binary64 with RNE. The logical API exposes five rounding modes, but runtime configuration and testing of all modes are not implemented.
- NaN payloads, signaling versus quiet NaNs, exception flags, traps, decimal formats, runtime FMA, and floating-point string conversions are not checked. SMT-LIB's FP theory itself does not distinguish signaling from quiet NaNs.
- Transcendental functions such as `sin` / `exp`, and proofs of error bounds relative to real-valued algorithms, require separate work.
- `unknown` and timeouts mean unproved; they do not establish truth or falsity. Positive SMT checks fail unless the expected `unsat` result is returned. The negative control only checks that a false theorem remains unproved; it does not claim that the solver produced a counterexample.
- Use `just prove` to verify both workspace modules, rather than relying only on targeted proofs that assume dependency packages.
- The project currently uses the local toolchain. Pinning toolchain distributions and solver versions for shared CI remains future work.

Possible extensions include compiler support for native FP proof lowering, cases from Berkeley TestFloat / SoftFloat, bitvector extraction and extension,
additional runtime bridge contracts, regular expressions, and runtime finite maps.
TestFloat / SoftFloat are not integrated into this repository yet.

## References

- [MoonBit Formal Verification](https://docs.moonbitlang.com/en/latest/language/verification.html): Contracts, external theories, and the trust model.
- [FSet in moonbit-community/verified](https://github.com/moonbit-community/verified/tree/main/libs/fset): A reference for importing finite-set models. This repository provides its own small binding API and usage examples.
- [A practical example of MoonBit formal verification (Japanese)](https://eng.mates.education/blog/b-moonbit-formal-verification/): Integer contracts, differences from runtime behavior, and floating-point differential tests.
- [Why3 ieee_float](https://www.why3.org/stdlib/ieee_float.html): Logical IEEE types and operations.
- [Why3 standard library](https://www.why3.org/stdlib/): Sources for the sequence, list, bag, finite-map, tree, stack, queue, and priority-queue specifications. The bundled files determine the available theories.
- [SMT-LIB FloatingPoint](https://smt-lib.org/theories-FloatingPoint.shtml): IEEE FP operations, rounding modes, and the scope of NaN representation.
- [Berkeley TestFloat](https://www.jhauser.us/arithmetic/TestFloat.html) / [SoftFloat](https://www.jhauser.us/arithmetic/SoftFloat.html): Arithmetic conformance testing and a software reference implementation.

- [Z3 Guide: Bitvectors](https://microsoft.github.io/z3guide/docs/theories/Bitvectors/): Fixed widths, signed/unsigned operations, and modular arithmetic.
- [Z3 Guide: Arrays](https://microsoft.github.io/z3guide/docs/theories/Arrays/): Select/store and extensional arrays.
- [Z3 Guide: Strings](https://microsoft.github.io/z3guide/docs/theories/Strings/): String operations and Unicode semantics.

## License

[Apache-2.0](LICENSE).
