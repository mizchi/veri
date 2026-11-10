// A reference interpreter for the supported fragment. It runs on MoonBit's
// own machine integers, strings and floats, so evaluating a term on runtime
// inputs is the executable counterpart of asking a solver for its value.

///|
fn sign_bit(width : Int32, bits : UInt64) -> Bool {
  ((bits >> (width - 1)) & 1UL) == 1UL
}

///|
/// The signed value of a `width`-bit pattern.
fn to_signed(width : Int32, bits : UInt64) -> Int64 {
  if width < 64 && sign_bit(width, bits) {
    (bits | (mask(width) ^ 0xffff_ffff_ffff_ffffUL)).reinterpret_as_int64()
  } else {
    bits.reinterpret_as_int64()
  }
}

///|
fn bv_udiv(width : Int32, x : UInt64, y : UInt64) -> UInt64 {
  if y == 0UL {
    mask(width)
  } else {
    x / y
  }
}

///|
fn bv_urem(x : UInt64, y : UInt64) -> UInt64 {
  if y == 0UL {
    x
  } else {
    x % y
  }
}

///|
fn bv_neg(width : Int32, x : UInt64) -> UInt64 {
  (0UL - x) & mask(width)
}

///|
/// SMT-LIB defines the signed operations by cases on the sign bits, which
/// also fixes division by zero and the overflowing `MIN / -1`.
fn bv_sdiv(width : Int32, x : UInt64, y : UInt64) -> UInt64 {
  match (sign_bit(width, x), sign_bit(width, y)) {
    (false, false) => bv_udiv(width, x, y)
    (true, false) => bv_neg(width, bv_udiv(width, bv_neg(width, x), y))
    (false, true) => bv_neg(width, bv_udiv(width, x, bv_neg(width, y)))
    (true, true) => bv_udiv(width, bv_neg(width, x), bv_neg(width, y))
  }
}

///|
fn bv_srem(width : Int32, x : UInt64, y : UInt64) -> UInt64 {
  match (sign_bit(width, x), sign_bit(width, y)) {
    (false, false) => bv_urem(x, y)
    (true, false) => bv_neg(width, bv_urem(bv_neg(width, x), y))
    (false, true) => bv_urem(x, bv_neg(width, y))
    (true, true) => bv_neg(width, bv_urem(bv_neg(width, x), bv_neg(width, y)))
  }
}

///|
fn bv_binary(op : Int32, width : Int32, x : UInt64, y : UInt64) -> UInt64 {
  let all = mask(width)
  match op {
    BV_ADD => (x + y) & all
    BV_SUB => (x - y) & all
    BV_MUL => (x * y) & all
    BV_UDIV => bv_udiv(width, x, y)
    BV_UREM => bv_urem(x, y)
    BV_SDIV => bv_sdiv(width, x, y)
    BV_SREM => bv_srem(width, x, y)
    BV_AND => x & y
    BV_OR => x | y
    BV_XOR => x ^ y
    BV_SHL => if y >= width.to_uint64() { 0UL } else { (x << y.to_int()) & all }
    BV_LSHR => if y >= width.to_uint64() { 0UL } else { x >> y.to_int() }
    _ =>
      // BV_ASHR
      if y >= width.to_uint64() {
        if sign_bit(width, x) {
          all
        } else {
          0UL
        }
      } else {
        (to_signed(width, x) >> y.to_int()).reinterpret_as_uint64() & all
      }
  }
}

///|
fn bv_compare(op : Int32, width : Int32, x : UInt64, y : UInt64) -> Bool {
  match op {
    BV_ULT => x < y
    BV_ULE => x <= y
    BV_SLT => to_signed(width, x) < to_signed(width, y)
    _ => to_signed(width, x) <= to_signed(width, y)
  }
}

///|
/// Euclidean division: the remainder is never negative.
fn int_div_mod(
  x : @bigint.BigInt,
  y : @bigint.BigInt,
) -> (@bigint.BigInt, @bigint.BigInt) raise SmtError {
  guard !y.is_zero() else { raise Unspecified("Integer division by zero") }
  let mut remainder = x % y
  if remainder < 0N {
    remainder = if y < 0N { remainder - y } else { remainder + y }
  }
  ((x - remainder) / y, remainder)
}

///|
fn int_to_bits(value : @bigint.BigInt, width : Int32) -> UInt64 {
  let modulus = 1N << width
  let mut reduced = value % modulus
  if reduced < 0N {
    reduced = reduced + modulus
  }
  reduced.to_uint64()
}

///|
fn f32(bits : UInt32) -> Float {
  Float::reinterpret_from_uint(bits)
}

///|
fn f64(bits : UInt64) -> Double {
  bits.reinterpret_as_double()
}

///|
fn fp32_binary(op : Int32, x : UInt32, y : UInt32) -> Value {
  let (a, b) = (f32(x), f32(y))
  Value::float32(
    match op {
      FP_ADD => a + b
      FP_SUB => a - b
      FP_MUL => a * b
      _ => a / b
    },
  )
}

///|
fn fp64_binary(op : Int32, x : UInt64, y : UInt64) -> Value {
  let (a, b) = (f64(x), f64(y))
  Value::float64(
    match op {
      FP_ADD => a + b
      FP_SUB => a - b
      FP_MUL => a * b
      _ => a / b
    },
  )
}

///|
fn internal(id : Int32) -> SmtError {
  SortMismatch("Evaluation reached an ill-sorted node \{id}")
}

///|
/// Evaluate one node whose operands already have values.
fn Context::eval_node(
  self : Context,
  id : Int32,
  model : Model,
) -> Value raise SmtError {
  let op = self.ops[id]
  let a = self.arg0[id]
  let b = self.arg1[id]
  let values = self.values
  match op {
    VAR => {
      let name = self.names[a]
      match model.values.get(name) {
        Some(value) => {
          guard value.sort() == self.sorts[id] else {
            raise SortMismatch(
              "\{name} is assigned a value of sort " + value.sort().to_smtlib(),
            )
          }
          value
        }
        None => raise Unspecified("No value for " + name)
      }
    }
    TRUE => Boolean(true)
    FALSE => Boolean(false)
    INT_SMALL => Integer(@bigint.BigInt::from_int(a))
    INT_BIG => Integer(self.bigs[a])
    BV_LIT => {
      let width = self.sorts[id].width()
      Bits(width, join_bits(a, b))
    }
    STR_LIT => Text(self.strings[a])
    F32_LIT => F32(a.reinterpret_as_uint())
    F64_LIT => F64(join_bits(a, b))
    NOT => {
      guard values[a] is Boolean(x) else { raise internal(id) }
      Boolean(!x)
    }
    AND | OR | XOR | IMPLIES => {
      guard values[a] is Boolean(x) && values[b] is Boolean(y) else {
        raise internal(id)
      }
      Boolean(
        match op {
          AND => x && y
          OR => x || y
          XOR => x != y
          _ => !x || y
        },
      )
    }
    EQUAL => Boolean(values[a] == values[b])
    DISTINCT => Boolean(values[a] != values[b])
    ITE => {
      guard values[a] is Boolean(condition) else { raise internal(id) }
      if condition {
        values[b]
      } else {
        values[self.arg2[id]]
      }
    }
    INT_ADD | INT_SUB | INT_MUL | INT_DIV | INT_MOD | INT_LE | INT_LT => {
      guard values[a] is Integer(x) && values[b] is Integer(y) else {
        raise internal(id)
      }
      match op {
        INT_ADD => Integer(x + y)
        INT_SUB => Integer(x - y)
        INT_MUL => Integer(x * y)
        INT_DIV => Integer(int_div_mod(x, y).0)
        INT_MOD => Integer(int_div_mod(x, y).1)
        INT_LE => Boolean(x <= y)
        _ => Boolean(x < y)
      }
    }
    INT_NEG | INT_ABS => {
      guard values[a] is Integer(x) else { raise internal(id) }
      Integer(if op == INT_NEG || x < 0N { -x } else { x })
    }
    BV_ADD
    | BV_SUB
    | BV_MUL
    | BV_UDIV
    | BV_UREM
    | BV_SDIV
    | BV_SREM
    | BV_AND
    | BV_OR
    | BV_XOR
    | BV_SHL
    | BV_LSHR
    | BV_ASHR => {
      guard values[a] is Bits(width, x) && values[b] is Bits(_, y) else {
        raise internal(id)
      }
      Bits(width, bv_binary(op, width, x, y))
    }
    BV_ULT | BV_ULE | BV_SLT | BV_SLE => {
      guard values[a] is Bits(width, x) && values[b] is Bits(_, y) else {
        raise internal(id)
      }
      Boolean(bv_compare(op, width, x, y))
    }
    BV_NOT => {
      guard values[a] is Bits(width, x) else { raise internal(id) }
      Bits(width, x ^ mask(width))
    }
    BV_NEG => {
      guard values[a] is Bits(width, x) else { raise internal(id) }
      Bits(width, bv_neg(width, x))
    }
    BV_CONCAT => {
      guard values[a] is Bits(high, x) && values[b] is Bits(low, y) else {
        raise internal(id)
      }
      Bits(high + low, (x << low) | y)
    }
    BV_EXTRACT => {
      guard values[a] is Bits(_, x) else { raise internal(id) }
      let low = self.arg2[id]
      let width = b - low + 1
      Bits(width, (x >> low) & mask(width))
    }
    BV_ZERO_EXTEND => {
      guard values[a] is Bits(width, x) else { raise internal(id) }
      Bits(width + b, x)
    }
    BV_SIGN_EXTEND => {
      guard values[a] is Bits(width, x) else { raise internal(id) }
      Bits(
        width + b,
        to_signed(width, x).reinterpret_as_uint64() & mask(width + b),
      )
    }
    BV_TO_NAT => {
      guard values[a] is Bits(_, x) else { raise internal(id) }
      Integer(@bigint.BigInt::from_uint64(x))
    }
    INT_TO_BV => {
      guard values[a] is Integer(x) else { raise internal(id) }
      Bits(b, int_to_bits(x, b))
    }
    SELECT => {
      guard values[a] is Table(table) else { raise internal(id) }
      table.select(values[b])
    }
    STORE => {
      guard values[a] is Table(table) else { raise internal(id) }
      Table(table.store(values[b], values[self.arg2[id]]))
    }
    CONST_ARRAY => {
      guard self.sorts[id] is Array(index, _) else { raise internal(id) }
      Table(ArrayValue::constant(index, values[a]))
    }
    STR_CONCAT
    | STR_CONTAINS
    | STR_PREFIX_OF
    | STR_SUFFIX_OF
    | STR_LT
    | STR_LE => {
      guard values[a] is Text(x) && values[b] is Text(y) else {
        raise internal(id)
      }
      match op {
        STR_CONCAT => Text(x + y)
        STR_CONTAINS => Boolean(x.contains(y))
        STR_PREFIX_OF => Boolean(y.has_prefix(x))
        STR_SUFFIX_OF => Boolean(y.has_suffix(x))
        STR_LT => Boolean(str_compare(x, y) < 0)
        _ => Boolean(str_compare(x, y) <= 0)
      }
    }
    STR_LEN => {
      guard values[a] is Text(x) else { raise internal(id) }
      Integer(@bigint.BigInt::from_int(x.char_length()))
    }
    STR_AT => {
      guard values[a] is Text(x) && values[b] is Integer(index) else {
        raise internal(id)
      }
      Text(str_substr(x, clamp(index), 1))
    }
    STR_SUBSTR => {
      guard values[a] is Text(x) &&
        values[b] is Integer(start) &&
        values[self.arg2[id]] is Integer(count) else {
        raise internal(id)
      }
      Text(str_substr(x, clamp(start), clamp(count)))
    }
    STR_INDEX_OF => {
      guard values[a] is Text(x) &&
        values[b] is Text(part) &&
        values[self.arg2[id]] is Integer(start) else {
        raise internal(id)
      }
      Integer(@bigint.BigInt::from_int(str_index_of(x, part, clamp(start))))
    }
    STR_REPLACE => {
      guard values[a] is Text(x) &&
        values[b] is Text(from) &&
        values[self.arg2[id]] is Text(to) else {
        raise internal(id)
      }
      Text(str_replace(x, from, to))
    }
    STR_TO_INT => {
      guard values[a] is Text(x) else { raise internal(id) }
      Integer(str_to_int(x))
    }
    STR_FROM_INT => {
      guard values[a] is Integer(x) else { raise internal(id) }
      Text(if x < 0N { "" } else { x.to_string() })
    }
    FP_ADD | FP_SUB | FP_MUL | FP_DIV =>
      match (values[a], values[b]) {
        (F32(x), F32(y)) => fp32_binary(op, x, y)
        (F64(x), F64(y)) => fp64_binary(op, x, y)
        _ => raise internal(id)
      }
    FP_EQ | FP_LT | FP_LE => {
      let order = match (values[a], values[b]) {
        (F32(x), F32(y)) => f32(x).to_double().compare(f32(y).to_double())
        (F64(x), F64(y)) => f64(x).compare(f64(y))
        _ => raise internal(id)
      }
      let unordered = match (values[a], values[b]) {
        (F32(x), F32(y)) => x == NAN32 || y == NAN32
        (F64(x), F64(y)) => x == NAN64 || y == NAN64
        _ => false
      }
      Boolean(
        !unordered &&
        (match op {
          FP_EQ => order == 0
          FP_LT => order < 0
          _ => order <= 0
        }),
      )
    }
    FP_SQRT =>
      match values[a] {
        F32(x) => Value::float32(f32(x).sqrt())
        F64(x) => Value::float64(f64(x).sqrt())
        _ => raise internal(id)
      }
    FP_NEG =>
      match values[a] {
        F32(x) => F32(if x == NAN32 { x } else { x ^ 0x8000_0000U })
        F64(x) => F64(if x == NAN64 { x } else { x ^ 0x8000_0000_0000_0000UL })
        _ => raise internal(id)
      }
    FP_ABS =>
      match values[a] {
        F32(x) => F32(if x == NAN32 { x } else { x & 0x7fff_ffffU })
        F64(x) => F64(if x == NAN64 { x } else { x & 0x7fff_ffff_ffff_ffffUL })
        _ => raise internal(id)
      }
    FP_IS_NAN =>
      match values[a] {
        F32(x) => Boolean(x == NAN32)
        F64(x) => Boolean(x == NAN64)
        _ => raise internal(id)
      }
    FP_IS_INFINITE =>
      match values[a] {
        F32(x) => Boolean((x & 0x7fff_ffffU) == 0x7f80_0000U)
        F64(x) =>
          Boolean((x & 0x7fff_ffff_ffff_ffffUL) == 0x7ff0_0000_0000_0000UL)
        _ => raise internal(id)
      }
    FP_IS_ZERO =>
      match values[a] {
        F32(x) => Boolean((x & 0x7fff_ffffU) == 0U)
        F64(x) => Boolean((x & 0x7fff_ffff_ffff_ffffUL) == 0UL)
        _ => raise internal(id)
      }
    FP_FROM_BITS =>
      match values[a] {
        Bits(32, x) => F32(canonical32(x.to_uint()))
        Bits(_, x) => F64(canonical64(x))
        _ => raise internal(id)
      }
    _ =>
      // FP_CONVERT
      match (values[a], self.sorts[id]) {
        (F32(x), Float64) => Value::float64(f32(x).to_double())
        (F64(x), Float32) => Value::float32(Float::from_double(f64(x)))
        (value, _) => value
      }
  }
}

///|
/// The value of `term` when its constants take the values in `model`.
///
/// Semantics follow SMT-LIB 2: bitvector arithmetic wraps, `bvudiv` by zero
/// is all ones, shifts by at least the width saturate, string positions
/// count code points, and floating-point arithmetic rounds to nearest even.
/// Raises `Unspecified` when the result depends on integer division by zero
/// or on a constant the model leaves out, except where `and`, `or`, `=>` or
/// `ite` decide the result from their other operands.
pub fn Context::eval(
  self : Context,
  term : Term,
  model : Model,
) -> Value raise SmtError {
  self.visit([term])
  let generation = self.generation
  let values = self.values
  let filler = Boolean(false)
  while values.length() < self.ops.length() {
    values.push(filler)
  }
  // Reuse the reference counts as "this node has no specified value" flags:
  // printing is finished with them, and -generation cannot be a count.
  let open = self.refs
  let mut reason = ""
  for index in 0..<self.order.length() {
    let id = self.order[index]
    let op = self.ops[id]
    let a = self.arg0[id]
    let b = self.arg1[id]
    let children = arity[op]
    let pending = children > 0 &&
      (
        open[a] == -generation ||
        (children > 1 && open[b] == -generation) ||
        (children > 2 && open[self.arg2[id]] == -generation)
      )
    if pending {
      // Only the connectives that ignore an operand can still be decided.
      let decided : Value? = match op {
        AND =>
          if (open[a] != -generation && values[a] is Boolean(false)) ||
            (open[b] != -generation && values[b] is Boolean(false)) {
            Some(Boolean(false))
          } else {
            None
          }
        OR =>
          if (open[a] != -generation && values[a] is Boolean(true)) ||
            (open[b] != -generation && values[b] is Boolean(true)) {
            Some(Boolean(true))
          } else {
            None
          }
        IMPLIES =>
          if (open[a] != -generation && values[a] is Boolean(false)) ||
            (open[b] != -generation && values[b] is Boolean(true)) {
            Some(Boolean(true))
          } else {
            None
          }
        ITE =>
          if open[a] != -generation && values[a] is Boolean(condition) {
            let chosen = if condition { b } else { self.arg2[id] }
            if open[chosen] != -generation {
              Some(values[chosen])
            } else {
              None
            }
          } else {
            None
          }
        _ => None
      }
      match decided {
        Some(value) => values[id] = value
        None => open[id] = -generation
      }
      continue
    }
    values[id] = self.eval_node(id, model) catch {
      Unspecified(message) => {
        if reason.is_empty() {
          reason = message
        }
        open[id] = -generation
        filler
      }
      error => raise error
    }
  }
  guard open[term.id] != -generation else { raise Unspecified(reason) }
  values[term.id]
}

///|
/// Evaluate and decode to a runtime type.
pub fn[T : Encode] Context::eval_as(
  self : Context,
  term : Term,
  model : Model,
) -> T raise SmtError {
  let value = self.eval(term, model)
  match T::from_value(value) {
    Some(result) => result
    None => raise SortMismatch("Value of sort " + value.sort().to_smtlib())
  }
}
