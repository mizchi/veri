///|
/// Exact encoding for non-NaN results, or any NaN encoding.
#derive(Eq, Debug)
pub(all) enum Expected {
  Bits(UInt32)
  AnyNaN
}

///|
pub extend Expected with Eq::{not_equal, equal}

///|
pub extend Expected with @debug.Debug::{to_repr}

///|
/// Compare an observed result with a reference, preserving the sign of zero.
pub fn matches(actual : Float, expected : Expected) -> Bool {
  match expected {
    Bits(bits) => actual.reinterpret_as_uint() == bits
    AnyNaN => actual.is_nan()
  }
}
