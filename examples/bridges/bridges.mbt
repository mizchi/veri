///|
/// The callee's modular arithmetic contract is usable across module boundaries.
pub fn zero_after_max() -> UInt where { proof_ensure: result => result == 0U, } {
  @uint32.add(0xffffffffU, 1U)
}

///|
/// Connect a runtime return value to an element in the logical array model.
pub fn first_or(
  array : FixedArray[Int],
  fallback : Int,
) -> Int where {
  proof_ensure: result => {
    if array.length() > 0 {
      result ==
      @arrays.select(@runtime_array.model(array), @integer.from_int(0))
    } else {
      result == fallback
    }
  },
} {
  match @runtime_array.get(array, 0) {
    Some(value) => value
    None => fallback
  }
}

///|
/// Composition of separately verified operations, even when addition wraps.
pub fn restore32(
  value : UInt,
  delta : UInt,
) -> UInt where {
  proof_require: 0U <= value && value <= 0xffffffffU,
  proof_require: 0U <= delta && delta <= 0xffffffffU,
  proof_ensure: result => result == value,
} {
  @uint32.sub(@uint32.add(value, delta), delta)
}

///|
/// Composition of separately verified operations, even when addition wraps.
pub fn restore64(
  value : UInt64,
  delta : UInt64,
) -> UInt64 where {
  proof_require: 0UL <= value && value <= 0xffffffffffffffffUL,
  proof_require: 0UL <= delta && delta <= 0xffffffffffffffffUL,
  proof_ensure: result => result == value,
} {
  @uint64.sub(@uint64.add(value, delta), delta)
}
