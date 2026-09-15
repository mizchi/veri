# IEEE 754 verification

[日本語](floating-point.ja.md) | [README](../README.md)

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
