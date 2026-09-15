///|
/// Clamp to [min, max], matching Int::clamp for min <= max.
/// The bounds precondition is proof-only; callers must supply a valid interval.
pub fn clamp(
  value : Int,
  min : Int,
  max : Int,
) -> Int where {
  proof_require: min <= max,
  proof_ensure: result => min <= result && result <= max,
  proof_ensure: result => !(min <= value && value <= max) || result == value,
  proof_ensure: result => value < min → result == min,
  proof_ensure: result => max < value → result == max,
} {
  if value < min {
    min
  } else if value > max {
    max
  } else {
    value
  }
}

///|
/// Clamp to the half-open interval [lower, upper).
pub fn clamp_half_open(
  value : Int,
  lower : Int,
  upper : Int,
) -> Int where {
  proof_require: lower < upper,
  proof_ensure: result => lower <= result && result < upper,
  proof_ensure: result => !(lower <= value && value < upper) || result == value,
  proof_ensure: result => value < lower → result == lower,
  proof_ensure: result => upper <= value → result == upper - 1,
} {
  if value < lower {
    lower
  } else if value >= upper {
    upper - 1
  } else {
    value
  }
}
