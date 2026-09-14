# veri

English | [日本語](README.ja.md)

A small foundation for formal verification in MoonBit, with reusable logical models and lemmas, implementations with contracts, and runtime differential checks.

Tools can verify IEEE 754 properties. This repository starts by checking execution results for **binary64 / roundTiesToEven (RNE)** and proving properties in Why3's IEEE model. It does not certify full compliance with the standard or prove the correctness of the MoonBit compiler or CPU.

## Running

Requirements: MoonBit, the bundled Why3 data at `~/.moon/share/why3/`, Z3 on PATH, Node.js 24+, and just. The Node scripts have no external dependencies.

```sh
just doctor        # Check versions and bundled Why3 data
just verify        # Run proofs, negative controls, reference checks, and backend tests
```

To run individual checks:

```sh
just prove         # Prove the entire module: MoonBit → Why3 → SMT
just prove-machine # Prove bounds contracts with the bundled machine-integer prelude
just smt           # UNSAT proofs and a concrete SAT counterexample in the IEEE FP theory
just negative      # Check that a deliberately false theorem is not proved
just test js       # Run runtime checks
just test-backends # JS / wasm / wasm-gc / native
just test-release  # Run the same checks in optimized builds
just vectors       # Regenerate expected results from Z3
just vectors-check # Compare checked-in reference values with the current Z3 results
just fmt           # Format sources and generate public interfaces
```

The locally verified environment uses moon 0.1.20260904, moonc v0.10.12+1634b282e, and Z3 4.16.0.
In this toolchain, `moon prove` automatically uses `~/.moon/share/why3`. No separate Why3 installation is needed.
The selected paths and solver are recorded in `_build/verif/why3.conf`; proof results appear in `*.proof.json` files under that directory.

## Structure and guarantees

| Path | Contents | What is checked |
| --- | --- | --- |
| `libs/bounds` | Clamp to a half-open interval | Given valid bounds, the result lies within the interval and preserves inputs already in range |
| `libs/fset` | Bindings to Why3's finite-set model | Lemmas for empty sets, insertion, and union |
| `libs/ieee754` | Logical binary64 values and rounding modes | Lemmas about NaN, signed zero, and self-subtraction of finite values |
| `examples/models` | Examples importing the libraries | Use of the set and IEEE models from another package |
| `runtime/float64` | Result comparisons and reference cases | Four arithmetic operations and sqrt compared against Z3's IEEE FP theory |
| `checks/fp` | Small SMT-LIB specification checks | Properties over all inputs and counterexamples with fixed inputs |
| `checks/negative` | Deliberately false lemmas | False claims must not be reported as successfully proved |

`.mbt` files contain implementations, types, and contracts; `.mbtp` files contain logical models and lemmas.
Public APIs are listed in `pkg.generated.mbti`.
The abstract types in `libs/fset` and `libs/ieee754` are **proof-only**. They are not runtime sets or `Double` values.

A minimal example:

```moonbit
// Import mizchi/veri/libs/ieee754 and enable proof-enabled in moon.pkg.
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

## Scope of IEEE 754 verification

**Runtime checks** compare results against expected values for boundary inputs and reproducible samples.
There are currently 86 cases: 46 boundary cases and 40 samples. They cover rounding halfway cases,
subnormals, the smallest normal value, overflow, ±0, ±∞, NaN, and sqrt.
Inputs are specified as bit patterns. Expected values are generated with Z3's FP operations,
without using the host's JavaScript floating-point arithmetic.
These checks do not enumerate all inputs.

**Formal verification in the model** proves properties for every model value satisfying the stated preconditions.
Examples include “x - x is zero for finite x” and “negating a NaN produces a NaN.”
For properties that do not hold, such as associativity of addition, a concrete counterexample can be given:

```text
a = 2^53, b = -2^53, c = 0.5, rounding mode RNE

(a + b) + c = 0.5
a + (b + c) = 0.0
```

This counterexample is reproduced in both SMT and MoonBit.

**Connecting the model to actual MoonBit Double operations** requires further work.
In the tested toolchain, placing a Double comparison directly in `proof_ensure` produces
`unsupported primitive operator in logic body`.
The IEEE model can be imported with `#proof_external` / `#proof_import`, using the same mechanism as FSet,
but importing it does not prove that MoonBit's runtime operations agree with the model.
At this stage, differential tests check that agreement on selected inputs.

## Trusted boundary and limitations

- The type mappings, argument order, and Why3 symbol mappings in `#proof_external` / `#proof_import`, along with Why3, the solver, and MoonBit's translation, are trusted. No custom `proof_axiomatized` declarations are used.
- Default integer proofs use mathematical integers. The bounds package is also proved separately with the bundled machine-integer model. `lower < upper` is a caller precondition, not a runtime input check.
- The runtime check profile is binary64 with RNE. The logical API exposes five rounding modes, but runtime configuration and testing of all modes are not implemented.
- NaN payloads, signaling versus quiet NaNs, exception flags, traps, decimal formats, binary32, runtime FMA, and string conversions are not checked. SMT-LIB's FP theory itself does not distinguish signaling from quiet NaNs.
- Transcendental functions such as `sin` / `exp`, and proofs of error bounds relative to real-valued algorithms, require separate work.
- `unknown` and timeouts mean unproved; they do not establish truth or falsity. Positive SMT checks fail unless the expected `unsat` result is returned. The negative control only checks that a false theorem remains unproved; it does not claim that the solver produced a counterexample.
- Use `just prove` to verify the entire module, rather than relying only on targeted proofs that assume dependency packages.
- The project currently uses the local toolchain. Pinning toolchain distributions and solver versions for shared CI remains future work.

Possible extensions include binary32, cases from Berkeley TestFloat / SoftFloat, verification of bit-vector representations,
contracts connecting implementations to their models, and Seq / Map models alongside sets.
TestFloat / SoftFloat are not integrated into this repository yet.

## References

- [MoonBit Formal Verification](https://docs.moonbitlang.com/en/latest/language/verification.html): Contracts, external theories, and the trust model.
- [FSet in moonbit-community/verified](https://github.com/moonbit-community/verified/tree/main/libs/fset): A reference for importing finite-set models. This repository provides its own small binding API and usage examples.
- [A practical example of MoonBit formal verification (Japanese)](https://eng.mates.education/blog/b-moonbit-formal-verification/): Integer contracts, differences from runtime behavior, and floating-point differential tests.
- [Why3 ieee_float](https://www.why3.org/stdlib/ieee_float.html): Logical IEEE types and operations.
- [SMT-LIB FloatingPoint](https://smt-lib.org/theories-FloatingPoint.shtml): IEEE FP operations, rounding modes, and the scope of NaN representation.
- [Berkeley TestFloat](https://www.jhauser.us/arithmetic/TestFloat.html) / [SoftFloat](https://www.jhauser.us/arithmetic/SoftFloat.html): Arithmetic conformance testing and a software reference implementation.
