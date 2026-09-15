# Bitvectors, orders, and numeric models

[日本語](numerics.ja.md) | [README](../README.md)

## Bitvector API

Import `"mizchi/veri/bitvector"` in `moon.pkg` for all four widths. Bring the types into scope in a `.mbt` file:

```moonbit
using @bitvector {type Bv8, type Bv16, type Bv32, type Bv64}
```

Proofs in `.mbtp` and runtime contracts then use `Bv32::add(x, y)`, `Bv64::add(x, y)`, `Bv32::of_integer(n)`, and the corresponding type methods. The types retain their distinct Why3 `bv.BV8` / `bv.BV16` / `bv.BV32` / `bv.BV64` representations. The current `.mbtp` parser requires the `using` form for imported type methods. This replaces the previous per-width package imports and free functions.

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
