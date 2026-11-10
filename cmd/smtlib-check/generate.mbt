///|
/// Deterministic xorshift64*, so a failing seed reproduces everywhere.
priv struct Random {
  mut state : UInt64
}

///|
fn Random::next(self : Random) -> UInt64 {
  let mut x = self.state
  x = x ^ (x >> 12)
  x = x ^ (x << 25)
  x = x ^ (x >> 27)
  self.state = x
  x * 0x2545_f491_4f6c_dd1dUL
}

///|
fn Random::below(self : Random, bound : Int32) -> Int32 {
  (self.next() >> 33).to_int() % bound
}

///|
/// Random bits biased toward the boundaries where semantics differ.
fn Random::word(self : Random) -> UInt64 {
  let raw = self.next()
  match raw % 10UL {
    0UL => 0UL
    1UL => 0xffff_ffff_ffff_ffffUL
    2UL => 1UL
    3UL => 0x8000_0000_8000_0080UL
    4UL => 0x7fff_ffff_7fff_ff7fUL
    5UL => raw >> 60
    _ => raw
  }
}

///|
/// Characters that exercise escaping, UTF-16 pairs and code point order.
let alphabet : Array[String] = [
  "a", "b", "A", "0", "9", " ", "\"", "\\", "\n", "é", "\u{FFFD}", "😀", "\u{2FFFF}",
  "\\u{41}", "|", "(", ";",
]

///|
/// Float patterns: zeros, subnormals, infinities and NaNs appear often.
fn Random::float_bits(self : Random) -> UInt64 {
  let raw = self.next()
  match raw % 12UL {
    0UL => 0UL
    1UL => 0x8000_0000_0000_0000UL
    2UL => 0x7ff0_0000_0000_0000UL
    3UL => 0xfff0_0000_0000_0000UL
    4UL => 0x7ff8_0000_0000_0001UL
    5UL => raw & 0x800f_ffff_ffff_ffffUL
    6UL => 0x3ff0_0000_0000_0000UL
    7UL => (raw & 0x8000_0000_0000_0000UL) | 0x7fef_ffff_ffff_ffffUL
    _ => raw
  }
}

///|
fn Random::float32_bits(self : Random) -> UInt32 {
  let raw = self.next()
  match raw % 12UL {
    0UL => 0U
    1UL => 0x8000_0000U
    2UL => 0x7f80_0000U
    3UL => 0xff80_0000U
    4UL => 0x7fc0_0001U
    5UL => raw.to_uint() & 0x807f_ffffU
    6UL => 0x3f80_0000U
    7UL => (raw.to_uint() & 0x8000_0000U) | 0x7f7f_ffffU
    _ => raw.to_uint()
  }
}

///|
fn Random::value(
  self : Random,
  sort : @smtlib.Sort,
) -> @smtlib.Value raise @smtlib.SmtError {
  match sort {
    Bool => Boolean(self.below(2) == 0)
    Int =>
      match self.below(6) {
        0 => Integer(@bigint.BigInt::from_uint64(self.next()) * 0x1_0000_0001N)
        1 => Integer(-@bigint.BigInt::from_uint64(self.next()))
        2 => Integer(@bigint.BigInt::from_int(self.below(100000) - 50000))
        _ => Integer(@bigint.BigInt::from_int(self.below(9) - 4))
      }
    BitVec(width) => @smtlib.Value::bits(width, self.word())
    String => {
      let out = StringBuilder()
      for _ in 0..<self.below(5) {
        out.write_string(alphabet[self.below(alphabet.length())])
      }
      if self.below(4) == 0 {
        out.write_string(self.below(1000).to_string())
      }
      @smtlib.Value::text(out.to_string())
    }
    Float32 =>
      @smtlib.Value::float32(Float::reinterpret_from_uint(self.float32_bits()))
    Float64 => @smtlib.Value::float64(self.float_bits().reinterpret_as_double())
    Array(index, element) => {
      let mut table = @smtlib.ArrayValue::constant(index, self.value(element))
      for _ in 0..<self.below(4) {
        table = table.store(self.value(index), self.value(element))
      }
      Table(table)
    }
  }
}

///|
fn Random::width(self : Random) -> Int32 {
  match self.below(8) {
    0 => 1
    1 => 8
    2 => 16
    3 => 32
    4 => 64
    _ => 1 + self.below(64)
  }
}

///|
fn Random::index_sort(self : Random) -> @smtlib.Sort {
  match self.below(5) {
    0 => Bool
    1 => BitVec(1 + self.below(3))
    2 => String
    _ => Int
  }
}

///|
fn Random::scalar_sort(self : Random) -> @smtlib.Sort {
  match self.below(7) {
    0 => Bool
    1 => Int
    2 => String
    3 => Float32
    4 => Float64
    _ => BitVec(self.width())
  }
}

///|
/// Builds random well-sorted terms. With `variables`, some leaves are
/// constants whose values are recorded in `model`.
priv struct Generator {
  ctx : @smtlib.Context
  random : Random
  model : @smtlib.Model
  variables : Bool
  mut fresh : Int32
}

///|
fn Generator::leaf(
  self : Generator,
  sort : @smtlib.Sort,
) -> @smtlib.Term raise @smtlib.SmtError {
  let value = self.random.value(sort)
  if self.variables && self.random.below(3) == 0 {
    let name = "v\{self.fresh}"
    self.fresh += 1
    self.model.set(name, value)
    self.ctx.constant(name, sort)
  } else {
    self.ctx.value(value)
  }
}

///|
fn Generator::term(
  self : Generator,
  sort : @smtlib.Sort,
  depth : Int32,
) -> @smtlib.Term raise @smtlib.SmtError {
  let ctx = self.ctx
  let random = self.random
  if depth <= 0 || random.below(8) == 0 {
    return self.leaf(sort)
  }
  let d = depth - 1
  if random.below(12) == 0 {
    return ctx.ite(self.term(Bool, d), self.term(sort, d), self.term(sort, d))
  }
  if random.below(12) == 0 {
    let index = random.index_sort()
    return ctx.select(self.term(Array(index, sort), d), self.term(index, d))
  }
  match sort {
    Bool =>
      match random.below(20) {
        0 => ctx.not_(self.term(Bool, d))
        1 => ctx.and_(self.term(Bool, d), self.term(Bool, d))
        2 => ctx.or_(self.term(Bool, d), self.term(Bool, d))
        3 => ctx.xor(self.term(Bool, d), self.term(Bool, d))
        4 => ctx.implies(self.term(Bool, d), self.term(Bool, d))
        5 => {
          let operand = random.scalar_sort()
          ctx.eq(self.term(operand, d), self.term(operand, d))
        }
        6 => {
          let operand = random.scalar_sort()
          ctx.distinct(self.term(operand, d), self.term(operand, d))
        }
        7 => {
          let operand : @smtlib.Sort = Array(
            random.index_sort(),
            random.scalar_sort(),
          )
          let array = self.term(operand, d)
          // Mostly compare an array with a variant of itself.
          let other = if random.below(3) == 0 {
            self.term(operand, d)
          } else {
            guard operand is Array(index, element) else { array }
            ctx.store(array, self.term(index, d), self.term(element, d))
          }
          ctx.eq(array, other)
        }
        8 | 9 | 10 | 11 => {
          let operand : @smtlib.Sort = BitVec(random.width())
          let (x, y) = (self.term(operand, d), self.term(operand, d))
          match random.below(4) {
            0 => ctx.bv_ult(x, y)
            1 => ctx.bv_ule(x, y)
            2 => ctx.bv_slt(x, y)
            _ => ctx.bv_sle(x, y)
          }
        }
        12 => ctx.int_le(self.term(Int, d), self.term(Int, d))
        13 => ctx.int_lt(self.term(Int, d), self.term(Int, d))
        14 | 15 => {
          let (x, y) = (self.term(String, d), self.term(String, d))
          match random.below(5) {
            0 => ctx.str_contains(x, y)
            1 => ctx.str_prefix_of(x, y)
            2 => ctx.str_suffix_of(x, y)
            3 => ctx.str_lt(x, y)
            _ => ctx.str_le(x, y)
          }
        }
        _ => {
          let operand : @smtlib.Sort = if random.below(2) == 0 {
            Float32
          } else {
            Float64
          }
          let (x, y) = (self.term(operand, d), self.term(operand, d))
          match random.below(6) {
            0 => ctx.fp_eq(x, y)
            1 => ctx.fp_lt(x, y)
            2 => ctx.fp_le(x, y)
            3 => ctx.fp_is_nan(x)
            4 => ctx.fp_is_infinite(x)
            _ => ctx.fp_is_zero(x)
          }
        }
      }
    Int =>
      match random.below(12) {
        0 => ctx.int_add(self.term(Int, d), self.term(Int, d))
        1 => ctx.int_sub(self.term(Int, d), self.term(Int, d))
        2 => ctx.int_mul(self.term(Int, d), self.term(Int, d))
        3 => ctx.int_neg(self.term(Int, d))
        4 => ctx.int_abs(self.term(Int, d))
        5 => ctx.int_div(self.term(Int, d), self.term(Int, d))
        6 => ctx.int_mod(self.term(Int, d), self.term(Int, d))
        7 => ctx.bv_to_int(self.term(BitVec(random.width()), d))
        8 => ctx.str_length(self.term(String, d))
        9 =>
          ctx.str_index_of(
            self.term(String, d),
            self.term(String, d),
            self.term(Int, d),
          )
        10 => ctx.str_to_int(self.term(String, d))
        _ => ctx.int_add(self.term(Int, d), ctx.int(1))
      }
    BitVec(width) => {
      let choice = random.below(22)
      if choice == 16 && width < 64 {
        // Extract `width` bits from a wider vector.
        let wider = width + 1 + random.below(64 - width)
        let low = random.below(wider - width + 1)
        return ctx.bv_extract(
          self.term(BitVec(wider), d),
          high=low + width - 1,
          low~,
        )
      }
      if (choice == 17 || choice == 18) && width > 1 {
        let narrower = 1 + random.below(width - 1)
        let operand = self.term(BitVec(narrower), d)
        return if choice == 17 {
          ctx.bv_zero_extend(operand, width~)
        } else {
          ctx.bv_sign_extend(operand, width~)
        }
      }
      if choice == 19 && width > 1 {
        let high = 1 + random.below(width - 1)
        return ctx.bv_concat(
          self.term(BitVec(high), d),
          self.term(BitVec(width - high), d),
        )
      }
      if choice == 20 {
        return ctx.int_to_bv(self.term(Int, d), width~)
      }
      if choice == 14 {
        return ctx.bv_not(self.term(sort, d))
      }
      if choice == 15 {
        return ctx.bv_neg(self.term(sort, d))
      }
      let (x, y) = (self.term(sort, d), self.term(sort, d))
      match choice % 14 {
        0 => ctx.bv_add(x, y)
        1 => ctx.bv_sub(x, y)
        2 => ctx.bv_mul(x, y)
        3 => ctx.bv_udiv(x, y)
        4 => ctx.bv_urem(x, y)
        5 => ctx.bv_sdiv(x, y)
        6 => ctx.bv_srem(x, y)
        7 => ctx.bv_and(x, y)
        8 => ctx.bv_or(x, y)
        9 => ctx.bv_xor(x, y)
        10 => ctx.bv_shl(x, y)
        11 => ctx.bv_lshr(x, y)
        12 => ctx.bv_ashr(x, y)
        _ => ctx.bv_add(x, ctx.bv_not(y))
      }
    }
    String =>
      match random.below(6) {
        0 => ctx.str_concat(self.term(String, d), self.term(String, d))
        1 => ctx.str_at(self.term(String, d), self.term(Int, d))
        2 =>
          ctx.str_substr(
            self.term(String, d),
            self.term(Int, d),
            self.term(Int, d),
          )
        3 =>
          ctx.str_replace(
            self.term(String, d),
            self.term(String, d),
            self.term(String, d),
          )
        4 => ctx.str_from_int(self.term(Int, d))
        _ => ctx.str_concat(self.term(String, d), ctx.string("a"))
      }
    Float32 | Float64 =>
      match random.below(10) {
        0 => ctx.fp_add(self.term(sort, d), self.term(sort, d))
        1 => ctx.fp_sub(self.term(sort, d), self.term(sort, d))
        2 => ctx.fp_mul(self.term(sort, d), self.term(sort, d))
        3 => ctx.fp_div(self.term(sort, d), self.term(sort, d))
        4 => ctx.fp_sqrt(self.term(sort, d))
        5 => ctx.fp_neg(self.term(sort, d))
        6 => ctx.fp_abs(self.term(sort, d))
        7 =>
          ctx.fp_from_bits(
            self.term(BitVec(if sort == Float32 { 32 } else { 64 }), d),
          )
        8 =>
          ctx.fp_convert(
            self.term(if sort == Float32 { Float64 } else { Float32 }, d),
            to=sort,
          )
        _ => ctx.fp_add(self.term(sort, d), self.term(sort, d))
      }
    Array(index, element) =>
      match random.below(3) {
        0 => ctx.const_array(index, self.term(element, d))
        _ =>
          ctx.store(
            self.term(sort, d),
            self.term(index, d),
            self.term(element, d),
          )
      }
  }
}
