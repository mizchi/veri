///|
/// Proved representability check; it never casts or truncates the value.
pub fn can_int_to_uint(
  x : Int,
) -> Bool where {
  proof_require: -2147483648 <= x && x <= 2147483647,
  proof_ensure: result => result == fits_uint(@integer.from_int(x)),
} {
  x >= 0
}

///|
/// Exact conversion, or None for an out-of-range input. Native casts are tested
/// against BigInt; their lowering is not supported by the current proof frontend.
/// The logical contract is converted_uint(@integer.from_int(x), result).
pub fn checked_int_to_uint(x : Int) -> UInt? {
  if can_int_to_uint(x) {
    Some(x.reinterpret_as_uint())
  } else {
    None
  }
}

///|
/// Proved representability check; it never casts or truncates the value.
pub fn can_int_to_int64(
  x : Int,
) -> Bool where {
  proof_require: -2147483648 <= x && x <= 2147483647,
  proof_ensure: result => result == fits_int64(@integer.from_int(x)),
} {
  true
}

///|
/// Exact widening conversion; every source value is representable.
/// Native value preservation is differential-tested against BigInt.
pub fn int_to_int64(x : Int) -> Int64 {
  x.to_int64()
}

///|
/// Proved representability check; it never casts or truncates the value.
pub fn can_int_to_uint64(
  x : Int,
) -> Bool where {
  proof_require: -2147483648 <= x && x <= 2147483647,
  proof_ensure: result => result == fits_uint64(@integer.from_int(x)),
} {
  x >= 0
}

///|
/// Exact conversion, or None for an out-of-range input. Native casts are tested
/// against BigInt; their lowering is not supported by the current proof frontend.
/// The logical contract is converted_uint64(@integer.from_int(x), result).
pub fn checked_int_to_uint64(x : Int) -> UInt64? {
  if can_int_to_uint64(x) {
    Some(x.to_uint64())
  } else {
    None
  }
}

///|
/// Proved representability check; it never casts or truncates the value.
pub fn can_uint_to_int(
  x : UInt,
) -> Bool where {
  proof_require: 0U <= x && x <= 4294967295U,
  proof_ensure: result => result == fits_int(@integer.from_uint(x)),
} {
  x <= 2147483647U
}

///|
/// Exact conversion, or None for an out-of-range input. Native casts are tested
/// against BigInt; their lowering is not supported by the current proof frontend.
/// The logical contract is converted_int(@integer.from_uint(x), result).
pub fn checked_uint_to_int(x : UInt) -> Int? {
  if can_uint_to_int(x) {
    Some(x.reinterpret_as_int())
  } else {
    None
  }
}

///|
/// Proved representability check; it never casts or truncates the value.
pub fn can_uint_to_int64(
  x : UInt,
) -> Bool where {
  proof_require: 0U <= x && x <= 4294967295U,
  proof_ensure: result => result == fits_int64(@integer.from_uint(x)),
} {
  true
}

///|
/// Exact widening conversion; every source value is representable.
/// Native value preservation is differential-tested against BigInt.
pub fn uint_to_int64(x : UInt) -> Int64 {
  x.to_int64()
}

///|
/// Proved representability check; it never casts or truncates the value.
pub fn can_uint_to_uint64(
  x : UInt,
) -> Bool where {
  proof_require: 0U <= x && x <= 4294967295U,
  proof_ensure: result => result == fits_uint64(@integer.from_uint(x)),
} {
  true
}

///|
/// Exact widening conversion; every source value is representable.
/// Native value preservation is differential-tested against BigInt.
pub fn uint_to_uint64(x : UInt) -> UInt64 {
  x.to_uint64()
}

///|
/// Proved representability check; it never casts or truncates the value.
pub fn can_int64_to_int(
  x : Int64,
) -> Bool where {
  proof_require: -9223372036854775808L <= x && x <= 9223372036854775807L,
  proof_ensure: result => result == fits_int(@integer.from_int64(x)),
} {
  x >= -2147483648L && x <= 2147483647L
}

///|
/// Exact conversion, or None for an out-of-range input. Native casts are tested
/// against BigInt; their lowering is not supported by the current proof frontend.
/// The logical contract is converted_int(@integer.from_int64(x), result).
pub fn checked_int64_to_int(x : Int64) -> Int? {
  if can_int64_to_int(x) {
    Some(x.to_int())
  } else {
    None
  }
}

///|
/// Proved representability check; it never casts or truncates the value.
pub fn can_int64_to_uint(
  x : Int64,
) -> Bool where {
  proof_require: -9223372036854775808L <= x && x <= 9223372036854775807L,
  proof_ensure: result => result == fits_uint(@integer.from_int64(x)),
} {
  x >= 0L && x <= 4294967295L
}

///|
/// Exact conversion, or None for an out-of-range input. Native casts are tested
/// against BigInt; their lowering is not supported by the current proof frontend.
/// The logical contract is converted_uint(@integer.from_int64(x), result).
pub fn checked_int64_to_uint(x : Int64) -> UInt? {
  if can_int64_to_uint(x) {
    Some(x.reinterpret_as_uint64().to_uint())
  } else {
    None
  }
}

///|
/// Proved representability check; it never casts or truncates the value.
pub fn can_int64_to_uint64(
  x : Int64,
) -> Bool where {
  proof_require: -9223372036854775808L <= x && x <= 9223372036854775807L,
  proof_ensure: result => result == fits_uint64(@integer.from_int64(x)),
} {
  x >= 0L
}

///|
/// Exact conversion, or None for an out-of-range input. Native casts are tested
/// against BigInt; their lowering is not supported by the current proof frontend.
/// The logical contract is converted_uint64(@integer.from_int64(x), result).
pub fn checked_int64_to_uint64(x : Int64) -> UInt64? {
  if can_int64_to_uint64(x) {
    Some(x.reinterpret_as_uint64())
  } else {
    None
  }
}

///|
/// Proved representability check; it never casts or truncates the value.
pub fn can_uint64_to_int(
  x : UInt64,
) -> Bool where {
  proof_require: 0UL <= x && x <= 18446744073709551615UL,
  proof_ensure: result => result == fits_int(@integer.from_uint64(x)),
} {
  x <= 2147483647UL
}

///|
/// Exact conversion, or None for an out-of-range input. Native casts are tested
/// against BigInt; their lowering is not supported by the current proof frontend.
/// The logical contract is converted_int(@integer.from_uint64(x), result).
pub fn checked_uint64_to_int(x : UInt64) -> Int? {
  if can_uint64_to_int(x) {
    Some(x.to_int())
  } else {
    None
  }
}

///|
/// Proved representability check; it never casts or truncates the value.
pub fn can_uint64_to_uint(
  x : UInt64,
) -> Bool where {
  proof_require: 0UL <= x && x <= 18446744073709551615UL,
  proof_ensure: result => result == fits_uint(@integer.from_uint64(x)),
} {
  x <= 4294967295UL
}

///|
/// Exact conversion, or None for an out-of-range input. Native casts are tested
/// against BigInt; their lowering is not supported by the current proof frontend.
/// The logical contract is converted_uint(@integer.from_uint64(x), result).
pub fn checked_uint64_to_uint(x : UInt64) -> UInt? {
  if can_uint64_to_uint(x) {
    Some(x.to_uint())
  } else {
    None
  }
}

///|
/// Proved representability check; it never casts or truncates the value.
pub fn can_uint64_to_int64(
  x : UInt64,
) -> Bool where {
  proof_require: 0UL <= x && x <= 18446744073709551615UL,
  proof_ensure: result => result == fits_int64(@integer.from_uint64(x)),
} {
  x <= 9223372036854775807UL
}

///|
/// Exact conversion, or None for an out-of-range input. Native casts are tested
/// against BigInt; their lowering is not supported by the current proof frontend.
/// The logical contract is converted_int64(@integer.from_uint64(x), result).
pub fn checked_uint64_to_int64(x : UInt64) -> Int64? {
  if can_uint64_to_int64(x) {
    Some(x.reinterpret_as_int64())
  } else {
    None
  }
}
