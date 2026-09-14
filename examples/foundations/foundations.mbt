///|
/// Compose the runtime gcd contract with its mathematical divisibility model.
pub fn common_factor(
  x : UInt,
  y : UInt,
) -> UInt where {
  proof_require: 0U <= x && x <= 0xffffffffU,
  proof_require: 0U <= y && y <= 0xffffffffU,
  proof_ensure: result => {
    @logic_number.divides(@integer.from_uint(result), @integer.from_uint(x))
  },
  proof_ensure: result => {
    @logic_number.divides(@integer.from_uint(result), @integer.from_uint(y))
  },
} {
  @number.gcd(x, y)
}
