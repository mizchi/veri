// Runtime operations are checked against Z3 references. These wrappers do not
// carry proof contracts: the current compiler cannot lower FP primitives.

///|
/// Reinterpret an encoding. NaN payload preservation is not part of the contract.
pub fn from_bits(bits : UInt64) -> Double {
  bits.reinterpret_as_double()
}

///|
pub fn to_bits(value : Double) -> UInt64 {
  value.reinterpret_as_uint64()
}

///|
/// One binary64 operation in the default RNE runtime profile.
pub fn add(x : Double, y : Double) -> Double {
  x + y
}

///|
/// One binary64 operation in the default RNE runtime profile.
pub fn sub(x : Double, y : Double) -> Double {
  x - y
}

///|
/// One binary64 operation in the default RNE runtime profile.
pub fn mul(x : Double, y : Double) -> Double {
  x * y
}

///|
/// One binary64 operation in the default RNE runtime profile.
pub fn div(x : Double, y : Double) -> Double {
  x / y
}

///|
pub fn sqrt(x : Double) -> Double {
  x.sqrt()
}

///|
pub fn neg(x : Double) -> Double {
  -x
}

///|
pub fn abs(x : Double) -> Double {
  x.abs()
}

///|
pub fn is_nan(x : Double) -> Bool {
  x.is_nan()
}

///|
pub fn is_infinite(x : Double) -> Bool {
  x.is_inf()
}

///|
/// IEEE comparison: NaN is unordered, and signed zeros compare equal.
pub fn eq(x : Double, y : Double) -> Bool {
  x == y
}

///|
/// IEEE comparison: NaN is unordered, and signed zeros compare equal.
pub fn less(x : Double, y : Double) -> Bool {
  x < y
}

///|
/// Narrow with RNE, including overflow and underflow.
pub fn to_float(value : Double) -> Float {
  Float::from_double(value)
}
