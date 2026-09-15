# Proof architecture and runtime correspondence

[日本語](architecture.ja.md) | [README](../README.md)

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
| `FixedArray[T]` | `@runtime_array.model(a)` → `SmtArray[Integer, T]`, plus `a.length()` | Reads, range validation and update contracts under both preludes; see [array updates](collections.md#fixedarray-updates-and-ranges) for the limits of before/after proofs |
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
and the Why3 arithmetic model for integer/BV correspondence. It also tries the real-valued and quantified-law routes described in [numeric models](numerics.md#orders-number-theory-reals-and-error-bounds). These encodings remain within the trusted Why3 boundary.
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
