# veri

English | [日本語](README.ja.md)

A small foundation for formal verification in MoonBit, with reusable logical models and lemmas, implementations with contracts, and runtime differential checks.

Proof bindings cover finite sets, sequences, lists, bags, finite maps, binary trees, fixed-size bitvectors, total arrays, strings, and IEEE floating point. For IEEE 754, the repository checks **binary32 and binary64 / roundTiesToEven (RNE)** execution results and proves properties in Why3's IEEE models. It does not certify full compliance with the standard or prove the correctness of the MoonBit compiler or CPU.

## Running

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
```

The locally verified environment uses moon 0.1.20260904, moonc v0.10.12+1634b282e, Z3 4.16.0, and CVC5 1.3.4.
In this toolchain, `moon prove` automatically uses `~/.moon/share/why3`. No separate Why3 installation is needed.
The `just` proof recipes generate `_build/why3/why3.conf` with Z3 and CVC5 encodings for bitvectors, quantified laws and real-valued IEEE models.
Proof results appear in `*.proof.json` files under each module’s `_build/verif/` directory.
Use `just prove`: bare `moon prove` uses only the default encoding and can time out on integer/BV bridge goals.

## Structure and guarantees

| Path | Contents | What is checked |
| --- | --- | --- |
| `bounds` | Clamp to a half-open interval | Given valid bounds, the result lies within the interval and preserves inputs already in range |
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
| `runtime/array` | FixedArray model and safe reads | Bounds checks and agreement with the model’s selected cell |
| `runtime/text` | Validated SMT-compatible text | Code point length, char_at, and substring checked against Z3 |
| `examples/bridges` | Runtime bridge clients | Contracts compose across module boundaries |
| `runtime/float32` / `runtime/float64` | Runtime FP APIs and exact reference comparisons | Arithmetic, sqrt, neg/abs, comparisons, classification, and non-NaN bit roundtrips |
| `runtime/float_conversions` | Precision conversion checks | Float ↔ Double compared against Z3, including rounding boundaries |
| `examples/floating` | Runtime FP usage | Different rounding precision in Float and Double |
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
    └── collections/
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

Import `"mizchi/veri/bitvector"` in `moon.pkg` for both widths. Bring the types into scope in a `.mbt` file:

```moonbit
using @bitvector {type Bv32, type Bv64}
```

Proofs in `.mbtp` and runtime contracts then use `Bv32::add(x, y)`, `Bv64::add(x, y)`, `Bv32::of_integer(n)`, and the corresponding type methods. The types retain their distinct Why3 `bv.BV32` / `bv.BV64` representations. The current `.mbtp` parser requires the `using` form for imported type methods. This replaces the previous per-width package imports and free functions.

Public lemmas have width suffixes, such as `@laws.addition_wraps32()` / `addition_wraps64()` in `bitvector/laws` and `integer_roundtrip32` / `integer_roundtrip64` in `bitvector/laws/integers`. Keeping integer conversion laws separate limits quantified proof context. `examples/bitvector/widths.mbtp` proves that the value 2^32 wraps in Bv32 but is preserved in Bv64 using a single package import. `just prove-machine` also checks these laws and the example with machine integers.

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

## QuickCheck properties

The 37 positive properties under `bounds/` and `runtime/` use
`moonbitlang/core/quickcheck`, each running 1,000 accepted cases with seed
`20260914`. Generated sizes grow up to 64, or 128 for operation traces and red-black balance. They run
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

## Collection benchmarks

`benchmarks/collections` uses [MoonBit's benchmark API](https://docs.moonbitlang.com/en/latest/language/benchmarks.html)
through `moon bench --release --no-parallelize`. It measures 12 workloads at
256 and 2,048 elements, producing 30 comparisons per backend. Each implementation
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
| Binary-tree traversal | `core/immut/sorted_set` | Materialize the same ordered unique contents from balanced and left-skewed trees |

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

The [recorded measurements](benchmarks/collections/RESULTS.md) show that the
current implementations **do not meet a universal no-slowdown target**. These
comparisons include representation, allocation, and algorithm differences; they
do not isolate proof-contract overhead. Proof-only `seq/list/bag/fmap/bintree`
bindings have no runtime operations to benchmark. Rerun on your deployment
backend and workload before relying on a performance comparison.

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
| `runtime/stack` | `empty/push/pop/peek/is_empty`; linked list | O(1) |
| `runtime/queue` | `empty/push/pop/peek/is_empty`; front list and reversed back list | Push/peek O(1); pop amortized O(1), worst-case O(n) |
| `runtime/pqueue` | `empty/push/pop/peek/is_empty`; Int skew heap, duplicates retained | Push/pop amortized O(log n), peek O(1) |
| `runtime/bintree` | `empty/node/inorder`; generic binary tree | Constructors O(1); inorder O(n) |
| `runtime/bintree/search` | `empty/insert/contains`; Int red-black tree without duplicates | Insert/contains O(log n) |

Costs describe states built through the public APIs and are not formally proved. Queue updates
normalize the front list, so repeated peeks do not repeat reversal. Amortized costs
for the queue and skew heap apply to a single update history; branching from old
snapshots can repeat work. The heap follows
[Sleator–Tarjan](https://www.cs.cmu.edu/~sleator/papers/Adjusting-Heaps.htm), and the tree follows
[Okasaki's insertion algorithm](https://www.cambridge.org/core/journals/journal-of-functional-programming/article/redblack-trees-in-a-functional-setting/62BC5EA75A2C95E3F6EE95AE3DADF0E5).
These differ from core's complete binary heap and size-balanced search tree.

BST `valid(tree)` retains its strict search-order meaning: `empty` establishes it
and `insert` preserves it. Insertion, including rotations, and lookup have proofs
of order, membership preservation, and search results. Red-black invariants
(black root, no red-red edge, equal black heights) are checked by shrinking
QuickCheck properties and long ascending/descending tests. Formal proofs of color
balance and complexity, and deletion, are not implemented.

The search-tree API now uses an opaque `@search.SearchTree` with internal colors.
Code passing `@tree.Tree[Int]` directly must instead construct a search tree with
`@search.empty()` and `insert`, enumerate with `@search.to_array(tree)`, and use
`@search.model` in contracts. The generic `runtime/bintree.Tree[T]` remains available
for arbitrary shapes. List length uses tail recursion; tree inorder uses a
continuation list for linear traversal. Its left branch is tail-recursive, while
its right branch and List append still use the call stack.
Stack/Queue/PriorityQueue/SearchTree use `#valtype` wrappers, and small operations
use `#inline` to reduce wrapper allocations. Updates also use `#owned` to avoid
unnecessary reference-count operations without changing the existing content/order
contracts. `proof_require`, `proof_ensure`, `proof_assert`, and `.mbtp` specifications
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
| `bitvector` | `bv.BV32` / `bv.BV64` | `add/sub/mul`, `udiv/urem`, `sdiv/srem`, `bw_and/or/xor/not`, `shl/lshr/ashr`, `ult/ule/slt/sle` |
| `arrays` | `map.Map`, `map.Const` | `select`, `store`, `const_array`, extensional `eq` |
| `strings` | `string.String` | `concat`, `length`, `char_at`, `substring`, `contains`, `prefix_of`, `suffix_of`, `index_of`, `replace`, `to_int/from_int`, `lt/le` |

Bitvectors have a fixed width; the initial API provides 32- and 64-bit types.
Signedness belongs to the operation, not the bit pattern. Addition, subtraction, and multiplication wrap modulo 2^width.
Shift counts are bitvectors of the same width: counts at least as large as the width do not wrap around.
`Bv32::width()` / `Bv64::width()` return the bitvector encoding of 32 or 64. Unsigned division by zero yields all ones in the SMT model;
this is not a claim about runtime division. Arbitrary widths, extraction, and extension are not exposed yet.
`of_integer` first reduces modulo 2^width, so it is defined for negative and oversized mathematical integers too.
`to_integer` returns the unsigned value, `modulus()` is 2^width, and `in_range` recognizes unsigned values.
The conversion laws prove `to_integer(of_integer(n)) = n mod 2^width` and `of_integer(to_integer(v)) = v`.

`SmtArray[K, V]` is a total map from every key to a value. It has no length, bounds check, or mutation.
`store` returns a new map. It can model memory, but does not by itself verify the bounds or behavior of a runtime array.

`Text` uses the SMT string model, whose alphabet covers U+0000..U+2FFFF.
Length counts code points, so an astral character within that alphabet has length one;
this is not MoonBit's runtime UTF-16 length. `char_at` returns a string, and `substring` takes a start and count.
Invalid positions produce empty strings, unsuccessful searches return -1, and `replace` changes the first occurrence.
`to_int/from_int` follow SMT nonnegative decimal conversion semantics; their `Int` values use the default mathematical-integer proof model.
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
| `FixedArray[T]` | `@runtime_array.model(a)` → `SmtArray[Integer, T]`, plus `a.length()` | `get` proves Some exactly in bounds with the selected model value, and None otherwise, under both preludes |
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
- Default integer proofs use mathematical integers. Bounds, unsigned wrapping adapters, FixedArray reads, collections, and their examples are also proved separately with the bundled machine-integer model. `lower < upper` is a caller precondition, not a runtime input check.
- The runtime check profile is binary32 and binary64 with RNE. The logical API exposes five rounding modes, but runtime configuration and testing of all modes are not implemented.
- NaN payloads, signaling versus quiet NaNs, exception flags, traps, decimal formats, runtime FMA, and floating-point string conversions are not checked. SMT-LIB's FP theory itself does not distinguish signaling from quiet NaNs.
- Transcendental functions such as `sin` / `exp`, and proofs of error bounds relative to real-valued algorithms, require separate work.
- `unknown` and timeouts mean unproved; they do not establish truth or falsity. Positive SMT checks fail unless the expected `unsat` result is returned. The negative control only checks that a false theorem remains unproved; it does not claim that the solver produced a counterexample.
- Use `just prove` to verify both workspace modules, rather than relying only on targeted proofs that assume dependency packages.
- The project currently uses the local toolchain. Pinning toolchain distributions and solver versions for shared CI remains future work.

Possible extensions include compiler support for native FP proof lowering, cases from Berkeley TestFloat / SoftFloat, bitvector extraction and extension,
additional runtime bridge contracts, regular expressions, balanced search trees, heap-based priority queues, and runtime finite maps.
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
