///|
/// Clamp to the half-open interval [lower, upper).
pub fn clamp(
  value : Int,
  lower : Int,
  upper : Int,
) -> Int where {
  proof_require: lower < upper,
  proof_ensure: result => lower <= result && result < upper,
  proof_ensure: result => !(lower <= value && value < upper) || result == value,
} {
  if value < lower {
    lower
  } else if value >= upper {
    upper - 1
  } else {
    value
  }
}
