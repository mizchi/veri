///|
/// A MoonBit runtime type with a fixed SMT-LIB sort.
///
/// Machine integers map to bitvectors of their width, so SMT terms follow the
/// same wrapping arithmetic as the runtime (`UInt` is `(_ BitVec 32)`, the
/// encoding `runtime/uint32.model` uses in proofs). `BigInt` is the unbounded
/// `Int` sort. `from_value` returns `None` for a value of another sort.
pub(open) trait Encode {
  fn sort() -> Sort
  fn to_value(Self) -> Value raise SmtError
  fn from_value(Value) -> Self?
}

///|
pub impl Encode for Bool with fn sort() {
  Bool
}

///|
pub impl Encode for Bool with fn to_value(self) {
  Boolean(self)
}

///|
pub impl Encode for Bool with fn from_value(value) {
  match value {
    Boolean(value) => Some(value)
    _ => None
  }
}

///|
pub impl Encode for @bigint.BigInt with fn sort() {
  Int
}

///|
pub impl Encode for @bigint.BigInt with fn to_value(self) {
  Integer(self)
}

///|
pub impl Encode for @bigint.BigInt with fn from_value(value) {
  match value {
    Integer(value) => Some(value)
    _ => None
  }
}

///|
pub impl Encode for Byte with fn sort() {
  BitVec(8)
}

///|
pub impl Encode for Byte with fn to_value(self) {
  Bits(8, self.to_uint64())
}

///|
pub impl Encode for Byte with fn from_value(value) {
  match value {
    Bits(8, bits) => Some(bits.to_byte())
    _ => None
  }
}

///|
pub impl Encode for UInt16 with fn sort() {
  BitVec(16)
}

///|
pub impl Encode for UInt16 with fn to_value(self) {
  Bits(16, self.to_uint64())
}

///|
pub impl Encode for UInt16 with fn from_value(value) {
  match value {
    Bits(16, bits) => Some(bits.to_uint16())
    _ => None
  }
}

///|
pub impl Encode for UInt32 with fn sort() {
  BitVec(32)
}

///|
pub impl Encode for UInt32 with fn to_value(self) {
  Bits(32, self.to_uint64())
}

///|
pub impl Encode for UInt32 with fn from_value(value) {
  match value {
    Bits(32, bits) => Some(bits.to_uint())
    _ => None
  }
}

///|
/// Two's complement: the same 32 bits as the `UInt` encoding.
pub impl Encode for Int32 with fn sort() {
  BitVec(32)
}

///|
pub impl Encode for Int32 with fn to_value(self) {
  Bits(32, self.reinterpret_as_uint().to_uint64())
}

///|
pub impl Encode for Int32 with fn from_value(value) {
  match value {
    Bits(32, bits) => Some(bits.to_uint().reinterpret_as_int())
    _ => None
  }
}

///|
pub impl Encode for UInt64 with fn sort() {
  BitVec(64)
}

///|
pub impl Encode for UInt64 with fn to_value(self) {
  Bits(64, self)
}

///|
pub impl Encode for UInt64 with fn from_value(value) {
  match value {
    Bits(64, bits) => Some(bits)
    _ => None
  }
}

///|
pub impl Encode for Int64 with fn sort() {
  BitVec(64)
}

///|
pub impl Encode for Int64 with fn to_value(self) {
  Bits(64, self.reinterpret_as_uint64())
}

///|
pub impl Encode for Int64 with fn from_value(value) {
  match value {
    Bits(64, bits) => Some(bits.reinterpret_as_int64())
    _ => None
  }
}

///|
pub impl Encode for String with fn sort() {
  String
}

///|
pub impl Encode for String with fn to_value(self) {
  Value::text(self)
}

///|
pub impl Encode for String with fn from_value(value) {
  match value {
    Text(value) => Some(value)
    _ => None
  }
}

///|
pub impl Encode for Float with fn sort() {
  Float32
}

///|
pub impl Encode for Float with fn to_value(self) {
  Value::float32(self)
}

///|
pub impl Encode for Float with fn from_value(value) {
  match value {
    F32(bits) => Some(Float::reinterpret_from_uint(bits))
    _ => None
  }
}

///|
pub impl Encode for Double with fn sort() {
  Float64
}

///|
pub impl Encode for Double with fn to_value(self) {
  Value::float64(self)
}

///|
pub impl Encode for Double with fn from_value(value) {
  match value {
    F64(bits) => Some(bits.reinterpret_as_double())
    _ => None
  }
}

///|
/// Encode any supported runtime value.
pub fn[T : Encode] to_value(value : T) -> Value raise SmtError {
  T::to_value(value)
}

///|
/// Decode a value of the expected runtime type; `None` on a sort mismatch.
pub fn[T : Encode] Value::decode(self : Value) -> T? {
  T::from_value(self)
}

///|
/// The array whose cells `0..cells.length()` hold `cells` and whose other
/// indices hold `default`. Only the first range denotes runtime cells, the
/// same convention as `runtime/array.model`.
pub fn[T : Encode] array_value(
  cells : ArrayView[T],
  default~ : T,
) -> Value raise SmtError {
  let mut table = ArrayValue::constant(Int, T::to_value(default))
  for index, cell in cells {
    table = table.store(
      Integer(@bigint.BigInt::from_int(index)),
      T::to_value(cell),
    )
  }
  Table(table)
}

///|
/// Read cells `0..length` of an integer-indexed array back into the runtime.
pub fn[T : Encode] Value::to_fixed_array(
  self : Value,
  length : Int32,
) -> FixedArray[T]? {
  guard self is Table(table) && table.index == Int && length >= 0 else {
    return None
  }
  guard T::from_value(table.default) is Some(default) else { return None }
  let cells = FixedArray::make(length, default)
  for index in 0..<length {
    guard T::from_value(table.select(Integer(@bigint.BigInt::from_int(index))))
      is Some(cell) else {
      return None
    }
    cells[index] = cell
  }
  Some(cells)
}

///|
/// A finite map as a total array: missing keys read `default`.
pub fn[K : Encode, V : Encode] map_value(
  map : Map[K, V],
  default~ : V,
) -> Value raise SmtError {
  let mut table = ArrayValue::constant(K::sort(), V::to_value(default))
  for key, value in map {
    table = table.store(K::to_value(key), V::to_value(value))
  }
  Table(table)
}

///|
/// Typed `select` on a decoded array value.
pub fn[K : Encode, V : Encode] Value::lookup(self : Value, key : K) -> V? {
  guard self is Table(table) && table.index == K::sort() else { return None }
  let key = K::to_value(key) catch { _ => return None }
  V::from_value(table.select(key))
}
