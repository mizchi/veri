// Runtime operations are checked against Z3 references. These wrappers do not
// carry proof contracts: the current compiler cannot lower FP primitives.

///|
/// Reinterpret an encoding. NaN payload preservation is not part of the contract.
pub fn from_bits(bits : UInt) -> Float {
  Float::reinterpret_from_uint(bits)
}

///|
pub fn to_bits(value : Float) -> UInt {
  value.reinterpret_as_uint()
}

///|
/// One binary32 operation in the default RNE runtime profile.
pub fn add(x : Float, y : Float) -> Float {
  x + y
}

///|
/// One binary32 operation in the default RNE runtime profile.
pub fn sub(x : Float, y : Float) -> Float {
  x - y
}

///|
/// One binary32 operation in the default RNE runtime profile.
pub fn mul(x : Float, y : Float) -> Float {
  x * y
}

///|
/// One binary32 operation in the default RNE runtime profile.
pub fn div(x : Float, y : Float) -> Float {
  x / y
}

///|
pub fn sqrt(x : Float) -> Float {
  x.sqrt()
}

///|
pub fn neg(x : Float) -> Float {
  -x
}

///|
pub fn abs(x : Float) -> Float {
  x.abs()
}

///|
pub fn is_nan(x : Float) -> Bool {
  x.is_nan()
}

///|
pub fn is_infinite(x : Float) -> Bool {
  x.is_inf()
}

///|
/// IEEE comparison: NaN is unordered, and signed zeros compare equal.
pub fn eq(x : Float, y : Float) -> Bool {
  x == y
}

///|
/// IEEE comparison: NaN is unordered, and signed zeros compare equal.
pub fn less(x : Float, y : Float) -> Bool {
  x < y
}

///|
/// Exact widening for finite values.
pub fn to_double(value : Float) -> Double {
  value.to_double()
}
