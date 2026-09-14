# veri

English | [日本語](README.ja.md)

A small foundation for formal verification in MoonBit, with reusable logical models and lemmas, implementations with contracts, and runtime differential checks.

Proof bindings cover finite sets, sequences, lists, bags, finite maps, binary trees, fixed-size bitvectors, total arrays, strings, and IEEE floating point. For IEEE 754, the repository checks **binary32 and binary64 / roundTiesToEven (RNE)** execution results and proves properties in Why3's IEEE models. It does not certify full compliance with the standard or prove the correctness of the MoonBit compiler or CPU.

## Running

Requirements: MoonBit, the bundled Why3 data at `~/.moon/share/why3/`, Z3 on PATH, Node.js 24+, and just. The Node scripts have no external dependencies.

```sh
just doctor        # Check versions and bundled Why3 data
just verify        # Run proofs, negative controls, reference checks, and backend tests
```

To run individual checks:

```sh
just prove         # Prove both workspace modules: MoonBit → Why3 → SMT
just prove-machine # Prove bounds, runtime bridges, and their example with machine integers
just prove-collections-machine # Prove collection implementations and clients with machine integers
just smt           # UNSAT proofs and SAT witnesses for FP, bitvectors, arrays, and strings
just negative      # Check that deliberately false claims in each model are not proved
just test js       # Run runtime checks
just quickcheck js # Run only the QuickCheck properties
just test-backends # JS / wasm / wasm-gc / native
just test-release  # Run the same checks in optimized builds
just fp-capabilities # Report native Float/Double proof-lowering support
just vectors       # Regenerate expected results from Z3
just vectors-check # Compare checked-in reference values with the current Z3 results
just fmt           # Format sources and generate public interfaces
```

The locally verified environment uses moon 0.1.20260904, moonc v0.10.12+1634b282e, and Z3 4.16.0.
In this toolchain, `moon prove` automatically uses `~/.moon/share/why3`. No separate Why3 installation is needed.
The `just` proof recipes generate `_build/why3/why3.conf` with native-BV and arithmetic encodings.
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
| `bv32` / `bv64` | Why3 fixed-size bitvector bindings | Operations and modular integer conversions |
| `bv32/laws` / `bv64/laws` | Bitvector lemmas, with integer laws in `laws/integers` | Bitwise laws, conversions in both directions, and unsigned value bounds |
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
├── bv32/
├── bv64/
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
Public package imports use paths such as `mizchi/veri/bounds`, `mizchi/veri/bv32`, and `mizchi/veri/arrays`.
Run `just prove` to prove the library and examples. In this toolchain, `moon prove`
on its own selects the current module; `moon -C examples prove` proves the examples.
Proof reports are written under each module's `_build/verif/` directory.

`.mbt` files contain implementations, types, and contracts; `.mbtp` files contain logical models and lemmas.
Public APIs are listed in `pkg.generated.mbti`.
The abstract types in `fset`, `seq`, `list`, `bag`, `fmap`, `bintree`, `ieee754`, `ieee754/float32`, `bv32`, `bv64`, `arrays`, and `strings` are **proof-only**. Runtime correspondence is provided separately by implementations under `runtime/` where stated.

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

## QuickCheck properties

The 32 positive properties under `bounds/` and `runtime/` use
`moonbitlang/core/quickcheck`, each running 1,000 accepted cases with seed
`20260914`. Generated sizes grow up to 64, or 128 for operation traces. They run
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
`counterexample=[Push(3)]`. This is the 33rd `quickcheck:*` test and verifies the
failure/shrinking path; it is not counted as a successful 1,000-case property.

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

The runtime packages implement persistent data structures. Recursive models
connect their actual constructors to Why3 lists, bags, and trees. The stack and
queue APIs follow Why3's LIFO/FIFO specifications; the priority queue follows
the minimum/multiplicity specification. Why3's abstract mutable `val` APIs are
not imported as executable implementations.

| Runtime package | Operations and representation | Cost |
| --- | --- | --- |
| `runtime/list` | `empty/cons/uncons/is_empty/append/reverse/length`; immutable linked spine | Basic operations O(1); append/reverse/length O(n) |
| `runtime/stack` | `empty/push/pop/peek/is_empty`; linked list | O(1) |
| `runtime/queue` | `empty/push/pop/peek/is_empty`; front list and reversed back list | Push O(1), pop/peek O(n) worst case |
| `runtime/pqueue` | `empty/push/pop/peek/is_empty`; sorted Int list, duplicates retained | Push O(n), pop/peek O(1) |
| `runtime/bintree` | `empty/node/inorder`; generic binary tree | Constructors O(1); inorder O(n²) worst case with list append |
| `runtime/bintree/search` | `empty/insert/contains`; strict Int BST without duplicates | O(height); no balancing |

Costs describe the implementations and are not formally proved. The two-list
queue has amortized O(1) push/pop along a single linear history; branching
from persistent snapshots or repeatedly peeking can repeat reversal work. The priority queue is an
initial verified sorted-list implementation, not a logarithmic heap. BST callers
must satisfy `valid(tree)`; `empty` establishes it and `insert` preserves it.
Deletion and balancing are not implemented.

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
MoonBit contracts / .mbtp → Why3 theories → SMT-LIB 2 → Z3
checks/**/*.smt2 ─────────────────────────→ SMT-LIB 2 → Z3
```

`#proof_external` maps a logical type; `#proof_import` maps a logical operation.
The `.smt2` checks use a separate direct path, without going through MoonBit or Why3.
These are proof APIs, not a runtime Z3 FFI or a general-purpose SMT-LIB 2 expression builder.

| Package | Why3 theory | Main operations |
| --- | --- | --- |
| `bv32` / `bv64` | `bv.BV32` / `bv.BV64` | `add/sub/mul`, `udiv/urem`, `sdiv/srem`, `bw_and/or/xor/not`, `shl/lshr/ashr`, `ult/ule/slt/sle` |
| `arrays` | `map.Map`, `map.Const` | `select`, `store`, `const_array`, extensional `eq` |
| `strings` | `string.String` | `concat`, `length`, `char_at`, `substring`, `contains`, `prefix_of`, `suffix_of`, `index_of`, `replace`, `to_int/from_int`, `lt/le` |

Bitvectors have a fixed width; the initial API provides 32- and 64-bit types.
Signedness belongs to the operation, not the bit pattern. Addition, subtraction, and multiplication wrap modulo 2^width.
Shift counts are bitvectors of the same width: counts at least as large as the width do not wrap around.
`width()` returns the bitvector encoding of 32 or 64. `udiv(x, zero())` yields all ones in the SMT model;
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
The generated `MoonBit_Auto` strategy tries both Z3 encodings: native bitvectors for bitwise laws,
and the Why3 arithmetic model for integer/BV correspondence. Both encodings remain within the trusted Why3 boundary.
The generator rejects unexpected upstream import layouts rather than silently deriving a different driver.
After splitting verification conditions, the strategy also uses Why3's
`compute_in_goal` to reduce concrete datatype constructors in structural models.
Doing this after splitting preserves the recursive hypotheses needed by list proofs.
`just prove` limits concurrent package jobs to two to avoid contention between
short solver time limits as the number of packages grows.

Bindings stay in `bv32` / `bv64`; their public lemmas now live in `bv32/laws` / `bv64/laws`,
with conversion lemmas in `bv32/laws/integers` / `bv64/laws/integers`.
Import the corresponding law package when calling a lemma. Keeping unrelated lemmas out of a caller's
proof context avoids expensive quantifier instantiation. `just prove` checks every package in both modules.
Negative controls use the same two encodings and include unbounded conversion identity and subtraction
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
