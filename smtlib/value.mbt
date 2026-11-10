///|
/// Canonical quiet NaN patterns: SMT-LIB has exactly one NaN per format.
const NAN32 : UInt32 = 0x7fc0_0000U

///|
const NAN64 : UInt64 = 0x7ff8_0000_0000_0000UL

///|
/// A concrete element of a `Sort`.
///
/// - `Bits(width, bits)` keeps `bits` below 2^width; signedness belongs to
///   the operation, exactly as in `mizchi/veri/bitvector`.
/// - `Text` holds well-formed UTF-16 within U+0000..U+2FFFF, the alphabet
///   shared with `mizchi/veri/runtime/text`.
/// - `F32` / `F64` hold IEEE bit patterns with every NaN canonicalized.
/// - `Table` is a total map, as in `mizchi/veri/arrays`.
#derive(Debug)
pub(all) enum Value {
  Boolean(Bool)
  Integer(@bigint.BigInt)
  Bits(Int32, UInt64)
  Text(String)
  F32(UInt32)
  F64(UInt64)
  Table(ArrayValue)
}

///|
pub extend Value with @debug.Debug::{to_repr}

///|
/// A total array: every index maps to `default` unless overridden.
/// Entries equal to the default are never stored, so two tables over an
/// infinite index sort are equal exactly when their fields are.
pub struct ArrayValue {
  index : Sort
  element : Sort
  default : Value
  priv entries : @immut_map.HashMap[Value, Value]
}

///|
pub impl @debug.Debug for ArrayValue with fn to_repr(self) {
  @debug.Repr(Table(self).to_smtlib())
}

///|
pub extend ArrayValue with @debug.Debug::{to_repr}

///|
pub impl Show for ArrayValue with fn output(self, logger) {
  logger.write_string(Table(self).to_smtlib())
}

///|
pub extend ArrayValue with Show::{to_string, output}

///|
pub fn Value::sort(self : Value) -> Sort {
  match self {
    Boolean(_) => Bool
    Integer(_) => Int
    Bits(width, _) => BitVec(width)
    Text(_) => String
    F32(_) => Float32
    F64(_) => Float64
    Table(table) => Array(table.index, table.element)
  }
}

///|
/// `self.sort() == sort` without building the sort.
fn Value::has_sort(self : Value, sort : Sort) -> Bool {
  match (self, sort) {
    (Boolean(_), Bool) => true
    (Integer(_), Int) => true
    (Bits(width, _), BitVec(expected)) => width == expected
    (Text(_), String) => true
    (F32(_), Float32) => true
    (F64(_), Float64) => true
    (Table(table), Array(index, element)) =>
      table.index == index && table.element == element
    _ => false
  }
}

///|
pub impl Eq for Value with fn equal(self, other) {
  match (self, other) {
    (Boolean(a), Boolean(b)) => a == b
    (Integer(a), Integer(b)) => a == b
    (Bits(wa, a), Bits(wb, b)) => wa == wb && a == b
    (Text(a), Text(b)) => a == b
    (F32(a), F32(b)) => a == b
    (F64(a), F64(b)) => a == b
    (Table(a), Table(b)) => a.equal_table(b)
    _ => false
  }
}

///|
pub extend Value with Eq::{not_equal, equal}

///|
pub impl Hash for Value with fn hash_combine(self, hasher) {
  match self {
    Boolean(value) => hasher.combine_bool(value)
    Integer(value) => hasher.combine(value)
    Bits(width, bits) => {
      hasher.combine_int(width)
      hasher.combine_uint64(bits)
    }
    Text(value) => hasher.combine_string(value)
    F32(bits) => hasher.combine_uint(bits)
    F64(bits) => hasher.combine_uint64(bits)
    // Extensionally equal finite-domain tables may differ in representation.
    Table(table) => hasher.combine(table.index)
  }
}

///|
pub extend Value with Hash::{hash, hash_combine}

///|
/// Number of elements of a finite index sort, when it is small enough to matter.
fn domain_size(sort : Sort) -> Int32? {
  match sort {
    Bool => Some(2)
    BitVec(width) if width < 30 => Some(1 << width)
    _ => None
  }
}

///|
fn ArrayValue::equal_table(self : ArrayValue, other : ArrayValue) -> Bool {
  guard self.index == other.index && self.element == other.element else {
    return false
  }
  if self.default == other.default {
    return self.entries == other.entries
  }
  // Different defaults agree only if a finite domain is overridden entirely.
  guard domain_size(self.index) is Some(size) else { return false }
  let mut covered = self.entries.length()
  for key in other.entries.keys() {
    if !self.entries.contains(key) {
      covered += 1
    }
  }
  guard covered == size else { return false }
  for key in self.entries.keys() {
    guard self.select(key) == other.select(key) else { return false }
  }
  for key in other.entries.keys() {
    guard self.select(key) == other.select(key) else { return false }
  }
  true
}

///|
/// The constant array `((as const (Array index element)) default)`.
pub fn ArrayValue::constant(index : Sort, default : Value) -> ArrayValue {
  {
    index,
    element: default.sort(),
    default,
    entries: @immut_map.HashMap::new(),
  }
}

///|
/// `select`: total, so a missing key reads the default.
pub fn ArrayValue::select(self : ArrayValue, key : Value) -> Value {
  match self.entries.get(key) {
    Some(value) => value
    None => self.default
  }
}

///|
/// `store`: persistent, sharing structure with the receiver.
pub fn ArrayValue::store(
  self : ArrayValue,
  key : Value,
  value : Value,
) -> ArrayValue {
  let entries = if value == self.default {
    if self.entries.contains(key) {
      self.entries.remove(key)
    } else {
      return self
    }
  } else {
    self.entries.add(key, value)
  }
  { ..self, entries, }
}

///|
/// Number of indices whose value differs from the default.
pub fn ArrayValue::override_count(self : ArrayValue) -> Int32 {
  self.entries.length()
}

///|
/// Overridden cells in an unspecified order.
pub fn ArrayValue::overrides(self : ArrayValue) -> Iter[(Value, Value)] {
  self.entries.iter()
}

///|
/// Clear the unused high bits so equal bitvectors have equal representations.
pub fn Value::bits(width : Int32, bits : UInt64) -> Value raise SmtError {
  check_width(width)
  Bits(width, bits & mask(width))
}

///|
/// Validate the SMT string alphabet through `runtime/text`.
pub fn Value::text(value : String) -> Value raise SmtError {
  guard @text.from_string(value) is Some(_) else {
    raise Unsupported("String is not well-formed UTF-16 within U+0000..U+2FFFF")
  }
  Text(value)
}

///|
pub fn Value::float32(value : Float) -> Value {
  F32(float32_bits(value))
}

///|
fn float32_bits(value : Float) -> UInt32 {
  if value.is_nan() {
    NAN32
  } else {
    value.reinterpret_as_uint()
  }
}

///|
fn float64_bits(value : Double) -> UInt64 {
  if value.is_nan() {
    NAN64
  } else {
    value.reinterpret_as_uint64()
  }
}

///|
pub fn Value::float64(value : Double) -> Value {
  F64(float64_bits(value))
}

///|
fn canonical32(bits : UInt32) -> UInt32 {
  if (bits & 0x7f80_0000U) == 0x7f80_0000U && (bits & 0x007f_ffffU) != 0U {
    NAN32
  } else {
    bits
  }
}

///|
fn canonical64(bits : UInt64) -> UInt64 {
  if (bits & 0x7ff0_0000_0000_0000UL) == 0x7ff0_0000_0000_0000UL &&
    (bits & 0x000f_ffff_ffff_ffffUL) != 0UL {
    NAN64
  } else {
    bits
  }
}

///|
/// Write the value as an SMT-LIB 2 term. Tables become a store chain over a
/// constant array, with keys in an unspecified order.
pub fn Value::write(self : Value, out : StringBuilder) -> Unit {
  match self {
    Boolean(value) => out.write_string(if value { "true" } else { "false" })
    Integer(value) => write_integer(out, value)
    Bits(width, bits) => write_bits(out, width, low_half(bits), high_half(bits))
    Text(value) => write_string_literal(out, value)
    F32(bits) => write_f32(out, bits.reinterpret_as_int())
    F64(bits) => write_f64(out, low_half(bits), high_half(bits))
    Table(table) => {
      let cells = table.entries.to_array()
      for _ in cells {
        out.write_string("(store ")
      }
      out.write_string("((as const ")
      Array(table.index, table.element).write(out)
      out.write_string(") ")
      table.default.write(out)
      out.write_string(")")
      for cell in cells {
        out.write_string(" ")
        cell.0.write(out)
        out.write_string(" ")
        cell.1.write(out)
        out.write_string(")")
      }
    }
  }
}

///|
pub fn Value::to_smtlib(self : Value) -> String {
  let out = StringBuilder()
  self.write(out)
  out.to_string()
}
