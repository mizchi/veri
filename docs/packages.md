# Packages and guarantees

[日本語](packages.ja.md) | [README](../README.md)

Proof bindings cover finite sets, sequences, lists, bags, finite maps, binary trees, fixed-size bitvectors, total arrays, strings, and IEEE floating point. For IEEE 754, the repository checks **binary32 and binary64 / roundTiesToEven (RNE)** execution results and proves properties in Why3's IEEE models. It does not certify full compliance with the standard or prove the correctness of the MoonBit compiler or CPU.

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
| `runtime/graph` | Immutable directed graphs, BFS, Dijkstra and topology | Complete shortest-path/topology checker proofs, independent models, graph/trace shrinking |
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
