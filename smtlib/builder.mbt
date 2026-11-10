// Term constructors. Each one checks operand sorts, so an ill-sorted script
// is rejected here rather than by the solver.

///|
fn Context::unary(
  self : Context,
  op : Int32,
  x : Term,
  expected : Sort,
  result : Sort,
  name : String,
) -> Term raise SmtError {
  let sort = self.sorts[x.id]
  guard sort == expected else { raise mismatch(name, sort) }
  self.intern(op, x.id, -1, -1, result)
}

///|
fn Context::binary(
  self : Context,
  op : Int32,
  x : Term,
  y : Term,
  expected : Sort,
  result : Sort,
  name : String,
) -> Term raise SmtError {
  let sort = self.sorts[x.id]
  guard sort == expected else { raise mismatch(name, sort) }
  let other = self.sorts[y.id]
  guard other == expected else { raise mismatch(name, other) }
  self.intern(op, x.id, y.id, -1, result)
}

// Core

///|
pub fn Context::not_(self : Context, x : Term) -> Term raise SmtError {
  self.unary(NOT, x, Bool, Bool, "not")
}

///|
pub fn Context::and_(self : Context, x : Term, y : Term) -> Term raise SmtError {
  self.binary(AND, x, y, Bool, Bool, "and")
}

///|
pub fn Context::or_(self : Context, x : Term, y : Term) -> Term raise SmtError {
  self.binary(OR, x, y, Bool, Bool, "or")
}

///|
pub fn Context::xor(self : Context, x : Term, y : Term) -> Term raise SmtError {
  self.binary(XOR, x, y, Bool, Bool, "xor")
}

///|
pub fn Context::implies(
  self : Context,
  x : Term,
  y : Term,
) -> Term raise SmtError {
  self.binary(IMPLIES, x, y, Bool, Bool, "=>")
}

///|
/// Conjunction of any number of terms; the empty conjunction is `true`.
pub fn Context::all(
  self : Context,
  terms : ArrayView[Term],
) -> Term raise SmtError {
  guard terms.length() > 0 else { return self.bool(true) }
  let mut result = terms[0]
  guard self.sorts[result.id] == Bool else {
    raise mismatch("and", self.sorts[result.id])
  }
  for term in terms[1:] {
    result = self.and_(result, term)
  }
  result
}

///|
/// Disjunction of any number of terms; the empty disjunction is `false`.
pub fn Context::any(
  self : Context,
  terms : ArrayView[Term],
) -> Term raise SmtError {
  guard terms.length() > 0 else { return self.bool(false) }
  let mut result = terms[0]
  guard self.sorts[result.id] == Bool else {
    raise mismatch("or", self.sorts[result.id])
  }
  for term in terms[1:] {
    result = self.or_(result, term)
  }
  result
}

///|
/// `=` at any sort. Arrays compare extensionally; floating-point values
/// compare as SMT values (`NaN = NaN`, `+0 ≠ -0`), unlike `fp_eq`.
pub fn Context::eq(self : Context, x : Term, y : Term) -> Term raise SmtError {
  let sort = self.sorts[x.id]
  guard self.sorts[y.id] == sort else { raise mismatch("=", self.sorts[y.id]) }
  self.intern(EQUAL, x.id, y.id, -1, Bool)
}

///|
pub fn Context::distinct(
  self : Context,
  x : Term,
  y : Term,
) -> Term raise SmtError {
  let sort = self.sorts[x.id]
  guard self.sorts[y.id] == sort else {
    raise mismatch("distinct", self.sorts[y.id])
  }
  self.intern(DISTINCT, x.id, y.id, -1, Bool)
}

///|
pub fn Context::ite(
  self : Context,
  condition : Term,
  then : Term,
  otherwise : Term,
) -> Term raise SmtError {
  guard self.sorts[condition.id] == Bool else {
    raise mismatch("ite", self.sorts[condition.id])
  }
  let sort = self.sorts[then.id]
  guard self.sorts[otherwise.id] == sort else {
    raise mismatch("ite", self.sorts[otherwise.id])
  }
  self.intern(ITE, condition.id, then.id, otherwise.id, sort)
}

// Ints: unbounded mathematical integers.

///|
pub fn Context::int_add(
  self : Context,
  x : Term,
  y : Term,
) -> Term raise SmtError {
  self.binary(INT_ADD, x, y, Int, Int, "+")
}

///|
pub fn Context::int_sub(
  self : Context,
  x : Term,
  y : Term,
) -> Term raise SmtError {
  self.binary(INT_SUB, x, y, Int, Int, "-")
}

///|
pub fn Context::int_mul(
  self : Context,
  x : Term,
  y : Term,
) -> Term raise SmtError {
  self.binary(INT_MUL, x, y, Int, Int, "*")
}

///|
pub fn Context::int_neg(self : Context, x : Term) -> Term raise SmtError {
  self.unary(INT_NEG, x, Int, Int, "-")
}

///|
/// Euclidean quotient: `x = y * div(x, y) + mod(x, y)` with `0 <= mod < |y|`.
/// SMT-LIB leaves division by zero unspecified.
pub fn Context::int_div(
  self : Context,
  x : Term,
  y : Term,
) -> Term raise SmtError {
  self.binary(INT_DIV, x, y, Int, Int, "div")
}

///|
pub fn Context::int_mod(
  self : Context,
  x : Term,
  y : Term,
) -> Term raise SmtError {
  self.binary(INT_MOD, x, y, Int, Int, "mod")
}

///|
pub fn Context::int_abs(self : Context, x : Term) -> Term raise SmtError {
  self.unary(INT_ABS, x, Int, Int, "abs")
}

///|
pub fn Context::int_le(
  self : Context,
  x : Term,
  y : Term,
) -> Term raise SmtError {
  self.binary(INT_LE, x, y, Int, Bool, "<=")
}

///|
pub fn Context::int_lt(
  self : Context,
  x : Term,
  y : Term,
) -> Term raise SmtError {
  self.binary(INT_LT, x, y, Int, Bool, "<")
}

///|
pub fn Context::int_ge(
  self : Context,
  x : Term,
  y : Term,
) -> Term raise SmtError {
  self.int_le(y, x)
}

///|
pub fn Context::int_gt(
  self : Context,
  x : Term,
  y : Term,
) -> Term raise SmtError {
  self.int_lt(y, x)
}

// FixedSizeBitVectors. Operation names follow `mizchi/veri/bitvector`.

///|
fn Context::bv_binary(
  self : Context,
  op : Int32,
  x : Term,
  y : Term,
  name : String,
) -> Term raise SmtError {
  let sort = self.sorts[x.id]
  guard sort is BitVec(_) else { raise mismatch(name, sort) }
  let other = self.sorts[y.id]
  guard other == sort else { raise mismatch(name, other) }
  self.intern(op, x.id, y.id, -1, sort)
}

///|
fn Context::bv_compare(
  self : Context,
  op : Int32,
  x : Term,
  y : Term,
  name : String,
) -> Term raise SmtError {
  let sort = self.sorts[x.id]
  guard sort is BitVec(_) else { raise mismatch(name, sort) }
  let other = self.sorts[y.id]
  guard other == sort else { raise mismatch(name, other) }
  self.intern(op, x.id, y.id, -1, Bool)
}

///|
fn Context::bv_unary(
  self : Context,
  op : Int32,
  x : Term,
  name : String,
) -> Term raise SmtError {
  let sort = self.sorts[x.id]
  guard sort is BitVec(_) else { raise mismatch(name, sort) }
  self.intern(op, x.id, -1, -1, sort)
}

///|
/// Addition modulo 2^width.
pub fn Context::bv_add(
  self : Context,
  x : Term,
  y : Term,
) -> Term raise SmtError {
  self.bv_binary(BV_ADD, x, y, "bvadd")
}

///|
pub fn Context::bv_sub(
  self : Context,
  x : Term,
  y : Term,
) -> Term raise SmtError {
  self.bv_binary(BV_SUB, x, y, "bvsub")
}

///|
pub fn Context::bv_mul(
  self : Context,
  x : Term,
  y : Term,
) -> Term raise SmtError {
  self.bv_binary(BV_MUL, x, y, "bvmul")
}

///|
/// Unsigned quotient; division by zero yields all ones.
pub fn Context::bv_udiv(
  self : Context,
  x : Term,
  y : Term,
) -> Term raise SmtError {
  self.bv_binary(BV_UDIV, x, y, "bvudiv")
}

///|
/// Unsigned remainder; a zero divisor yields the dividend.
pub fn Context::bv_urem(
  self : Context,
  x : Term,
  y : Term,
) -> Term raise SmtError {
  self.bv_binary(BV_UREM, x, y, "bvurem")
}

///|
/// Signed quotient truncated toward zero.
pub fn Context::bv_sdiv(
  self : Context,
  x : Term,
  y : Term,
) -> Term raise SmtError {
  self.bv_binary(BV_SDIV, x, y, "bvsdiv")
}

///|
/// Signed remainder with the sign of the dividend.
pub fn Context::bv_srem(
  self : Context,
  x : Term,
  y : Term,
) -> Term raise SmtError {
  self.bv_binary(BV_SREM, x, y, "bvsrem")
}

///|
pub fn Context::bv_and(
  self : Context,
  x : Term,
  y : Term,
) -> Term raise SmtError {
  self.bv_binary(BV_AND, x, y, "bvand")
}

///|
pub fn Context::bv_or(
  self : Context,
  x : Term,
  y : Term,
) -> Term raise SmtError {
  self.bv_binary(BV_OR, x, y, "bvor")
}

///|
pub fn Context::bv_xor(
  self : Context,
  x : Term,
  y : Term,
) -> Term raise SmtError {
  self.bv_binary(BV_XOR, x, y, "bvxor")
}

///|
pub fn Context::bv_not(self : Context, x : Term) -> Term raise SmtError {
  self.bv_unary(BV_NOT, x, "bvnot")
}

///|
pub fn Context::bv_neg(self : Context, x : Term) -> Term raise SmtError {
  self.bv_unary(BV_NEG, x, "bvneg")
}

///|
/// Shift left by an unsigned count; counts of at least the width give zero.
pub fn Context::bv_shl(
  self : Context,
  x : Term,
  y : Term,
) -> Term raise SmtError {
  self.bv_binary(BV_SHL, x, y, "bvshl")
}

///|
pub fn Context::bv_lshr(
  self : Context,
  x : Term,
  y : Term,
) -> Term raise SmtError {
  self.bv_binary(BV_LSHR, x, y, "bvlshr")
}

///|
/// Arithmetic shift right; large counts fill with the sign bit.
pub fn Context::bv_ashr(
  self : Context,
  x : Term,
  y : Term,
) -> Term raise SmtError {
  self.bv_binary(BV_ASHR, x, y, "bvashr")
}

///|
pub fn Context::bv_ult(
  self : Context,
  x : Term,
  y : Term,
) -> Term raise SmtError {
  self.bv_compare(BV_ULT, x, y, "bvult")
}

///|
pub fn Context::bv_ule(
  self : Context,
  x : Term,
  y : Term,
) -> Term raise SmtError {
  self.bv_compare(BV_ULE, x, y, "bvule")
}

///|
pub fn Context::bv_slt(
  self : Context,
  x : Term,
  y : Term,
) -> Term raise SmtError {
  self.bv_compare(BV_SLT, x, y, "bvslt")
}

///|
pub fn Context::bv_sle(
  self : Context,
  x : Term,
  y : Term,
) -> Term raise SmtError {
  self.bv_compare(BV_SLE, x, y, "bvsle")
}

///|
/// `x` supplies the high bits. The combined width must not exceed 64.
pub fn Context::bv_concat(
  self : Context,
  x : Term,
  y : Term,
) -> Term raise SmtError {
  guard self.sorts[x.id] is BitVec(high) else {
    raise mismatch("concat", self.sorts[x.id])
  }
  guard self.sorts[y.id] is BitVec(low) else {
    raise mismatch("concat", self.sorts[y.id])
  }
  check_width(high + low)
  self.intern(BV_CONCAT, x.id, y.id, -1, BitVec(high + low))
}

///|
/// Bits `high` down to `low`, inclusive, as a vector of `high - low + 1` bits.
pub fn Context::bv_extract(
  self : Context,
  x : Term,
  high~ : Int32,
  low~ : Int32,
) -> Term raise SmtError {
  guard self.sorts[x.id] is BitVec(width) else {
    raise mismatch("extract", self.sorts[x.id])
  }
  guard 0 <= low && low <= high && high < width else {
    raise Unsupported("extract \{high} \{low} from \{width} bits")
  }
  self.intern(BV_EXTRACT, x.id, high, low, BitVec(high - low + 1))
}

///|
/// Widen to `width` bits with zeros: the unsigned value is preserved.
pub fn Context::bv_zero_extend(
  self : Context,
  x : Term,
  width~ : Int32,
) -> Term raise SmtError {
  guard self.sorts[x.id] is BitVec(from) else {
    raise mismatch("zero_extend", self.sorts[x.id])
  }
  check_width(width)
  guard width >= from else {
    raise Unsupported("zero_extend from \{from} to \{width} bits")
  }
  self.intern(BV_ZERO_EXTEND, x.id, width - from, -1, BitVec(width))
}

///|
/// Widen to `width` bits with the sign bit: the signed value is preserved.
pub fn Context::bv_sign_extend(
  self : Context,
  x : Term,
  width~ : Int32,
) -> Term raise SmtError {
  guard self.sorts[x.id] is BitVec(from) else {
    raise mismatch("sign_extend", self.sorts[x.id])
  }
  check_width(width)
  guard width >= from else {
    raise Unsupported("sign_extend from \{from} to \{width} bits")
  }
  self.intern(BV_SIGN_EXTEND, x.id, width - from, -1, BitVec(width))
}

///|
/// The unsigned value as a mathematical integer (`bv2nat`).
pub fn Context::bv_to_int(self : Context, x : Term) -> Term raise SmtError {
  guard self.sorts[x.id] is BitVec(_) else {
    raise mismatch("bv2nat", self.sorts[x.id])
  }
  self.intern(BV_TO_NAT, x.id, -1, -1, Int)
}

///|
/// The integer reduced modulo 2^width (`int2bv`), defined for negative and
/// oversized integers like `Bv32::of_integer`.
pub fn Context::int_to_bv(
  self : Context,
  x : Term,
  width~ : Int32,
) -> Term raise SmtError {
  guard self.sorts[x.id] == Int else {
    raise mismatch("int2bv", self.sorts[x.id])
  }
  check_width(width)
  self.intern(INT_TO_BV, x.id, width, -1, BitVec(width))
}

// ArraysEx. Names follow `mizchi/veri/arrays`.

///|
pub fn Context::select(
  self : Context,
  array : Term,
  index : Term,
) -> Term raise SmtError {
  guard self.sorts[array.id] is Array(key, element) else {
    raise mismatch("select", self.sorts[array.id])
  }
  guard self.sorts[index.id] == key else {
    raise mismatch("select", self.sorts[index.id])
  }
  self.intern(SELECT, array.id, index.id, -1, element)
}

///|
pub fn Context::store(
  self : Context,
  array : Term,
  index : Term,
  value : Term,
) -> Term raise SmtError {
  let sort = self.sorts[array.id]
  guard sort is Array(key, element) else { raise mismatch("store", sort) }
  guard self.sorts[index.id] == key else {
    raise mismatch("store", self.sorts[index.id])
  }
  guard self.sorts[value.id] == element else {
    raise mismatch("store", self.sorts[value.id])
  }
  self.intern(STORE, array.id, index.id, value.id, sort)
}

///|
/// The array mapping every `index` to `value`.
pub fn Context::const_array(
  self : Context,
  index : Sort,
  value : Term,
) -> Term raise SmtError {
  check_sort(index)
  self.intern(CONST_ARRAY, value.id, -1, -1, Array(index, self.sorts[value.id]))
}

// Strings. Names follow `mizchi/veri/strings`; positions count code points.

///|
pub fn Context::str_concat(
  self : Context,
  x : Term,
  y : Term,
) -> Term raise SmtError {
  self.binary(STR_CONCAT, x, y, String, String, "str.++")
}

///|
pub fn Context::str_length(self : Context, x : Term) -> Term raise SmtError {
  self.unary(STR_LEN, x, String, Int, "str.len")
}

///|
/// The one-character string at `index`, or the empty string out of range.
pub fn Context::str_at(
  self : Context,
  x : Term,
  index : Term,
) -> Term raise SmtError {
  guard self.sorts[x.id] == String else {
    raise mismatch("str.at", self.sorts[x.id])
  }
  guard self.sorts[index.id] == Int else {
    raise mismatch("str.at", self.sorts[index.id])
  }
  self.intern(STR_AT, x.id, index.id, -1, String)
}

///|
/// At most `count` characters from `start`.
pub fn Context::str_substr(
  self : Context,
  x : Term,
  start : Term,
  count : Term,
) -> Term raise SmtError {
  guard self.sorts[x.id] == String else {
    raise mismatch("str.substr", self.sorts[x.id])
  }
  guard self.sorts[start.id] == Int else {
    raise mismatch("str.substr", self.sorts[start.id])
  }
  guard self.sorts[count.id] == Int else {
    raise mismatch("str.substr", self.sorts[count.id])
  }
  self.intern(STR_SUBSTR, x.id, start.id, count.id, String)
}

///|
/// Whether `x` contains `part`.
pub fn Context::str_contains(
  self : Context,
  x : Term,
  part : Term,
) -> Term raise SmtError {
  self.binary(STR_CONTAINS, x, part, String, Bool, "str.contains")
}

///|
/// Whether `prefix` starts `x`. SMT-LIB writes the prefix first.
pub fn Context::str_prefix_of(
  self : Context,
  prefix : Term,
  x : Term,
) -> Term raise SmtError {
  self.binary(STR_PREFIX_OF, prefix, x, String, Bool, "str.prefixof")
}

///|
pub fn Context::str_suffix_of(
  self : Context,
  suffix : Term,
  x : Term,
) -> Term raise SmtError {
  self.binary(STR_SUFFIX_OF, suffix, x, String, Bool, "str.suffixof")
}

///|
/// First position of `part` in `x` at or after `start`, or -1.
pub fn Context::str_index_of(
  self : Context,
  x : Term,
  part : Term,
  start : Term,
) -> Term raise SmtError {
  guard self.sorts[x.id] == String else {
    raise mismatch("str.indexof", self.sorts[x.id])
  }
  guard self.sorts[part.id] == String else {
    raise mismatch("str.indexof", self.sorts[part.id])
  }
  guard self.sorts[start.id] == Int else {
    raise mismatch("str.indexof", self.sorts[start.id])
  }
  self.intern(STR_INDEX_OF, x.id, part.id, start.id, Int)
}

///|
/// Replace the first occurrence of `from` in `x` by `to`.
pub fn Context::str_replace(
  self : Context,
  x : Term,
  from : Term,
  to : Term,
) -> Term raise SmtError {
  guard self.sorts[x.id] == String else {
    raise mismatch("str.replace", self.sorts[x.id])
  }
  guard self.sorts[from.id] == String else {
    raise mismatch("str.replace", self.sorts[from.id])
  }
  guard self.sorts[to.id] == String else {
    raise mismatch("str.replace", self.sorts[to.id])
  }
  self.intern(STR_REPLACE, x.id, from.id, to.id, String)
}

///|
/// The value of a nonempty string of decimal digits, otherwise -1.
pub fn Context::str_to_int(self : Context, x : Term) -> Term raise SmtError {
  self.unary(STR_TO_INT, x, String, Int, "str.to_int")
}

///|
/// Decimal digits of a nonnegative integer; the empty string when negative.
pub fn Context::str_from_int(self : Context, x : Term) -> Term raise SmtError {
  self.unary(STR_FROM_INT, x, Int, String, "str.from_int")
}

///|
/// Lexicographic order by code point.
pub fn Context::str_lt(
  self : Context,
  x : Term,
  y : Term,
) -> Term raise SmtError {
  self.binary(STR_LT, x, y, String, Bool, "str.<")
}

///|
pub fn Context::str_le(
  self : Context,
  x : Term,
  y : Term,
) -> Term raise SmtError {
  self.binary(STR_LE, x, y, String, Bool, "str.<=")
}

// FloatingPoint, binary32 and binary64. Arithmetic rounds to nearest, ties to
// even: the mode of MoonBit `Float` / `Double` and of `runtime/float32|64`.

///|
fn Context::fp_binary(
  self : Context,
  op : Int32,
  x : Term,
  y : Term,
  name : String,
) -> Term raise SmtError {
  let sort = self.sorts[x.id]
  guard sort is (Float32 | Float64) else { raise mismatch(name, sort) }
  let other = self.sorts[y.id]
  guard other == sort else { raise mismatch(name, other) }
  self.intern(op, x.id, y.id, -1, sort)
}

///|
fn Context::fp_compare(
  self : Context,
  op : Int32,
  x : Term,
  y : Term,
  name : String,
) -> Term raise SmtError {
  let sort = self.sorts[x.id]
  guard sort is (Float32 | Float64) else { raise mismatch(name, sort) }
  let other = self.sorts[y.id]
  guard other == sort else { raise mismatch(name, other) }
  self.intern(op, x.id, y.id, -1, Bool)
}

///|
fn Context::fp_unary(
  self : Context,
  op : Int32,
  x : Term,
  result : Sort?,
  name : String,
) -> Term raise SmtError {
  let sort = self.sorts[x.id]
  guard sort is (Float32 | Float64) else { raise mismatch(name, sort) }
  self.intern(op, x.id, -1, -1, result.unwrap_or(sort))
}

///|
pub fn Context::fp_add(
  self : Context,
  x : Term,
  y : Term,
) -> Term raise SmtError {
  self.fp_binary(FP_ADD, x, y, "fp.add")
}

///|
pub fn Context::fp_sub(
  self : Context,
  x : Term,
  y : Term,
) -> Term raise SmtError {
  self.fp_binary(FP_SUB, x, y, "fp.sub")
}

///|
pub fn Context::fp_mul(
  self : Context,
  x : Term,
  y : Term,
) -> Term raise SmtError {
  self.fp_binary(FP_MUL, x, y, "fp.mul")
}

///|
pub fn Context::fp_div(
  self : Context,
  x : Term,
  y : Term,
) -> Term raise SmtError {
  self.fp_binary(FP_DIV, x, y, "fp.div")
}

///|
pub fn Context::fp_sqrt(self : Context, x : Term) -> Term raise SmtError {
  self.fp_unary(FP_SQRT, x, None, "fp.sqrt")
}

///|
pub fn Context::fp_neg(self : Context, x : Term) -> Term raise SmtError {
  self.fp_unary(FP_NEG, x, None, "fp.neg")
}

///|
pub fn Context::fp_abs(self : Context, x : Term) -> Term raise SmtError {
  self.fp_unary(FP_ABS, x, None, "fp.abs")
}

///|
/// IEEE equality: false for NaN, true for `+0` and `-0`.
pub fn Context::fp_eq(
  self : Context,
  x : Term,
  y : Term,
) -> Term raise SmtError {
  self.fp_compare(FP_EQ, x, y, "fp.eq")
}

///|
pub fn Context::fp_lt(
  self : Context,
  x : Term,
  y : Term,
) -> Term raise SmtError {
  self.fp_compare(FP_LT, x, y, "fp.lt")
}

///|
pub fn Context::fp_le(
  self : Context,
  x : Term,
  y : Term,
) -> Term raise SmtError {
  self.fp_compare(FP_LE, x, y, "fp.leq")
}

///|
pub fn Context::fp_is_nan(self : Context, x : Term) -> Term raise SmtError {
  self.fp_unary(FP_IS_NAN, x, Some(Bool), "fp.isNaN")
}

///|
pub fn Context::fp_is_infinite(self : Context, x : Term) -> Term raise SmtError {
  self.fp_unary(FP_IS_INFINITE, x, Some(Bool), "fp.isInfinite")
}

///|
pub fn Context::fp_is_zero(self : Context, x : Term) -> Term raise SmtError {
  self.fp_unary(FP_IS_ZERO, x, Some(Bool), "fp.isZero")
}

///|
/// Reinterpret 32 or 64 bits in IEEE interchange format. Every NaN pattern
/// denotes the single SMT NaN.
pub fn Context::fp_from_bits(self : Context, x : Term) -> Term raise SmtError {
  let sort = match self.sorts[x.id] {
    BitVec(32) => Float32
    BitVec(64) => Float64
    other => raise mismatch("to_fp", other)
  }
  self.intern(FP_FROM_BITS, x.id, -1, -1, sort)
}

///|
/// Convert between binary32 and binary64, rounding to nearest even.
pub fn Context::fp_convert(
  self : Context,
  x : Term,
  to~ : Sort,
) -> Term raise SmtError {
  guard to is (Float32 | Float64) else { raise mismatch("to_fp", to) }
  guard self.sorts[x.id] is (Float32 | Float64) else {
    raise mismatch("to_fp", self.sorts[x.id])
  }
  self.intern(FP_CONVERT, x.id, -1, -1, to)
}
