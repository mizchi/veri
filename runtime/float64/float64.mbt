///|
/// Exact encoding for non-NaN results, or any NaN encoding.
pub(all) enum Expected {
  Bits(UInt64)
  AnyNaN
} derive(Eq, Debug)

///|
/// Compare an observed result with a reference, preserving the sign of zero.
pub fn matches(actual : Double, expected : Expected) -> Bool {
  match expected {
    Bits(bits) => actual.reinterpret_as_uint64() == bits
    AnyNaN => actual.is_nan()
  }
}
