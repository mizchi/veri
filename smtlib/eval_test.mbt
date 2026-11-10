///|
/// Deterministic xorshift64*: the same cases on every backend and run.
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
/// Mix uniformly random words with boundary values, which uniform sampling
/// would essentially never produce.
fn Random::word(self : Random) -> UInt64 {
  let raw = self.next()
  match raw % 8UL {
    0UL => 0UL
    1UL => 0xffff_ffff_ffff_ffffUL
    2UL => 0x8000_0000_8000_0000UL
    3UL => 0x7fff_ffff_7fff_ffffUL
    4UL => raw >> 59
    _ => raw
  }
}

///|
fn[T : @smtlib.Encode] value_of(
  ctx : @smtlib.Context,
  term : @smtlib.Term,
) -> T raise {
  ctx.eval_as(term, @smtlib.Model::new())
}

///|
test "32-bit bitvector terms compute native UInt and Int results" {
  let ctx = @smtlib.Context::new()
  let random : Random = { state: 0x9e37_79b9_7f4a_7c15UL, }
  for _ in 0..<2000 {
    let x = random.word().to_uint()
    let y = random.word().to_uint()
    let a = ctx.literal(x)
    let b = ctx.literal(y)
    let (sx, sy) = (x.reinterpret_as_int(), y.reinterpret_as_int())
    assert_eq((value_of(ctx, ctx.bv_add(a, b)) : UInt32), x + y)
    // The proved adapters and the interpreter agree with the native operators.
    assert_eq((value_of(ctx, ctx.bv_add(a, b)) : UInt32), @uint32.add(x, y))
    assert_eq((value_of(ctx, ctx.bv_sub(a, b)) : UInt32), @uint32.sub(x, y))
    assert_eq((value_of(ctx, ctx.bv_ult(a, b)) : Bool), @uint32.less(x, y))
    assert_eq((value_of(ctx, ctx.bv_mul(a, b)) : UInt32), x * y)
    assert_eq((value_of(ctx, ctx.bv_and(a, b)) : UInt32), x & y)
    assert_eq((value_of(ctx, ctx.bv_or(a, b)) : UInt32), x | y)
    assert_eq((value_of(ctx, ctx.bv_xor(a, b)) : UInt32), x ^ y)
    assert_eq((value_of(ctx, ctx.bv_not(a)) : UInt32), x ^ 0xffff_ffffU)
    assert_eq((value_of(ctx, ctx.bv_neg(a)) : UInt32), 0U - x)
    assert_eq((value_of(ctx, ctx.bv_ule(a, b)) : Bool), x <= y)
    assert_eq((value_of(ctx, ctx.bv_slt(a, b)) : Bool), sx < sy)
    assert_eq((value_of(ctx, ctx.bv_sle(a, b)) : Bool), sx <= sy)
    // The same bits read back as either signedness.
    assert_eq((value_of(ctx, ctx.bv_add(a, b)) : Int32), sx + sy)
    if y != 0U {
      assert_eq((value_of(ctx, ctx.bv_udiv(a, b)) : UInt32), x / y)
      assert_eq((value_of(ctx, ctx.bv_urem(a, b)) : UInt32), x % y)
      if !(sx == @int.MIN_VALUE && sy == -1) {
        assert_eq((value_of(ctx, ctx.bv_sdiv(a, b)) : Int32), sx / sy)
        assert_eq((value_of(ctx, ctx.bv_srem(a, b)) : Int32), sx % sy)
      }
    }
    // Native shifts are only compared where their count is in range.
    let count = (y % 32U).reinterpret_as_int()
    let c = ctx.literal(count)
    assert_eq((value_of(ctx, ctx.bv_shl(a, c)) : UInt32), x << count)
    assert_eq((value_of(ctx, ctx.bv_lshr(a, c)) : UInt32), x >> count)
    assert_eq((value_of(ctx, ctx.bv_ashr(a, c)) : Int32), sx >> count)
    // Widening preserves the unsigned or the signed value.
    assert_eq(
      (value_of(ctx, ctx.bv_zero_extend(a, width=64)) : UInt64),
      x.to_uint64(),
    )
    assert_eq(
      (value_of(ctx, ctx.bv_sign_extend(a, width=64)) : Int64),
      sx.to_int64(),
    )
    let integer : @bigint.BigInt = value_of(ctx, ctx.bv_to_int(a))
    assert_eq(integer, @bigint.BigInt::from_uint(x))
    assert_eq(
      (
        value_of(
          ctx,
          ctx.int_to_bv(ctx.integer(@bigint.BigInt::from_int(sx)), width=32),
        ) : Int32),
      sx,
    )
  }
}

///|
test "64-bit and narrow bitvector terms compute native results" {
  let ctx = @smtlib.Context::new()
  let random : Random = { state: 0x0123_4567_89ab_cdefUL, }
  for _ in 0..<2000 {
    let x = random.word()
    let y = random.word()
    let a = ctx.literal(x)
    let b = ctx.literal(y)
    let (sx, sy) = (x.reinterpret_as_int64(), y.reinterpret_as_int64())
    assert_eq((value_of(ctx, ctx.bv_add(a, b)) : UInt64), @uint64.add(x, y))
    assert_eq((value_of(ctx, ctx.bv_sub(a, b)) : UInt64), @uint64.sub(x, y))
    assert_eq((value_of(ctx, ctx.bv_ult(a, b)) : Bool), @uint64.less(x, y))
    assert_eq((value_of(ctx, ctx.bv_mul(a, b)) : UInt64), x * y)
    assert_eq((value_of(ctx, ctx.bv_slt(a, b)) : Bool), sx < sy)
    if y != 0UL {
      assert_eq((value_of(ctx, ctx.bv_udiv(a, b)) : UInt64), x / y)
      assert_eq((value_of(ctx, ctx.bv_urem(a, b)) : UInt64), x % y)
      if !(sx == @int64.MIN_VALUE && sy == -1L) {
        assert_eq((value_of(ctx, ctx.bv_sdiv(a, b)) : Int64), sx / sy)
        assert_eq((value_of(ctx, ctx.bv_srem(a, b)) : Int64), sx % sy)
      }
    }
    let count = (y % 64UL).to_int()
    let c = ctx.literal(count.to_uint64())
    assert_eq((value_of(ctx, ctx.bv_shl(a, c)) : UInt64), x << count)
    assert_eq((value_of(ctx, ctx.bv_lshr(a, c)) : UInt64), x >> count)
    assert_eq((value_of(ctx, ctx.bv_ashr(a, c)) : Int64), sx >> count)
    // Bytes: extraction and concatenation are the big-endian codec.
    let high : Byte = value_of(ctx, ctx.bv_extract(a, high=63, low=56))
    let low : Byte = value_of(ctx, ctx.bv_extract(a, high=7, low=0))
    assert_eq(high, (x >> 56).to_byte())
    assert_eq(low, x.to_byte())
    let pair : UInt16 = value_of(
      ctx,
      ctx.bv_concat(ctx.literal(high), ctx.literal(low)),
    )
    assert_eq(pair, (high.to_uint16() << 8) | low.to_uint16())
    let narrow : Byte = value_of(
      ctx,
      ctx.bv_add(ctx.literal(high), ctx.literal(low)),
    )
    assert_eq(narrow, high + low)
  }
}

///|
test "bitvector corner cases follow SMT-LIB, not machine traps" {
  let ctx = @smtlib.Context::new()
  let min = ctx.literal(@int.MIN_VALUE)
  let zero = ctx.literal(0)
  let seven = ctx.literal(7)
  assert_eq((value_of(ctx, ctx.bv_udiv(seven, zero)) : UInt32), 0xffff_ffffU)
  assert_eq((value_of(ctx, ctx.bv_urem(seven, zero)) : Int32), 7)
  assert_eq((value_of(ctx, ctx.bv_sdiv(seven, zero)) : Int32), -1)
  assert_eq((value_of(ctx, ctx.bv_sdiv(ctx.literal(-7), zero)) : Int32), 1)
  assert_eq((value_of(ctx, ctx.bv_srem(ctx.literal(-7), zero)) : Int32), -7)
  assert_eq(
    (value_of(ctx, ctx.bv_sdiv(min, ctx.literal(-1))) : Int32),
    @int.MIN_VALUE,
  )
  assert_eq((value_of(ctx, ctx.bv_srem(min, ctx.literal(-1))) : Int32), 0)
  let wide = ctx.literal(32)
  assert_eq((value_of(ctx, ctx.bv_shl(seven, wide)) : Int32), 0)
  assert_eq((value_of(ctx, ctx.bv_lshr(min, wide)) : Int32), 0)
  assert_eq((value_of(ctx, ctx.bv_ashr(min, wide)) : Int32), -1)
  assert_eq((value_of(ctx, ctx.bv_ashr(seven, ctx.literal(-1))) : Int32), 0)
  // Widths that are not a machine width keep exactly their own bits.
  let odd = ctx.bv(5, 0b10110UL)
  assert_eq(
    ctx.eval(ctx.bv_ashr(odd, ctx.bv(5, 2UL)), @smtlib.Model::new()),
    Bits(5, 0b11101UL),
  )
  assert_eq(
    ctx.eval(ctx.bv_mul(odd, odd), @smtlib.Model::new()),
    Bits(5, 0b00100UL),
  )
  assert_eq(
    ctx.eval(ctx.bv_slt(odd, ctx.bv(5, 1UL)), @smtlib.Model::new()),
    Boolean(true),
  )
}

///|
test "integer division is Euclidean and unspecified at zero" {
  let ctx = @smtlib.Context::new()
  for
    entry in [
      (7, 2, 3, 1),
      (-7, 2, -4, 1),
      (7, -2, -3, 1),
      (-7, -2, 4, 1),
      (6, 3, 2, 0),
      (-6, 3, -2, 0),
    ] {
    let (x, y) = (ctx.int(entry.0), ctx.int(entry.1))
    let quotient : @bigint.BigInt = value_of(ctx, ctx.int_div(x, y))
    let remainder : @bigint.BigInt = value_of(ctx, ctx.int_mod(x, y))
    assert_eq(quotient, @bigint.BigInt::from_int(entry.2))
    assert_eq(remainder, @bigint.BigInt::from_int(entry.3))
  }
  let n = ctx.constant("n", Int)
  let quotient = ctx.int_div(ctx.int(1), n)
  let model = @smtlib.Model::new()
  model.set("n", Integer(0N))
  let unspecified = try {
    ignore(ctx.eval(quotient, model))
    false
  } catch {
    Unspecified(_) => true
    _ => false
  }
  assert_true(unspecified)
  // A guard decides the result without the undefined operand.
  let guarded = ctx.ite(ctx.eq(n, ctx.int(0)), ctx.int(-1), quotient)
  assert_eq(ctx.eval(guarded, model), Integer(-1N))
  let safe = ctx.or_(ctx.eq(n, ctx.int(0)), ctx.int_gt(quotient, ctx.int(0)))
  assert_eq(ctx.eval(safe, model), Boolean(true))
  let big = ctx.integer(1N << 100)
  let wrapped : UInt64 = value_of(
    ctx,
    ctx.int_to_bv(ctx.int_sub(ctx.int(0), big), width=64),
  )
  assert_eq(wrapped, 0UL)
  let missing = try {
    ignore(ctx.eval(n, @smtlib.Model::new()))
    false
  } catch {
    Unspecified(_) => true
    _ => false
  }
  assert_true(missing)
}

///|
test "string terms count code points" {
  let ctx = @smtlib.Context::new()
  let text = ctx.literal("A😀é😀z")
  let empty = @smtlib.Model::new()
  let length : @bigint.BigInt = value_of(ctx, ctx.str_length(text))
  assert_eq(length, 5N)
  let cases : Array[(@smtlib.Term, String)] = [
    (ctx.str_at(text, ctx.int(1)), "😀"),
    (ctx.str_at(text, ctx.int(5)), ""),
    (ctx.str_at(text, ctx.int(-1)), ""),
    (ctx.str_substr(text, ctx.int(1), ctx.int(3)), "😀é😀"),
    (ctx.str_substr(text, ctx.int(3), ctx.int(100)), "😀z"),
    (ctx.str_substr(text, ctx.int(2), ctx.int(0)), ""),
    (ctx.str_substr(text, ctx.int(0), ctx.integer(1N << 80)), "A😀é😀z"),
    (ctx.str_replace(text, ctx.literal("😀"), ctx.literal("-")), "A-é😀z"),
    (ctx.str_replace(text, ctx.literal(""), ctx.literal(">")), ">A😀é😀z"),
    (ctx.str_replace(text, ctx.literal("q"), ctx.literal(">")), "A😀é😀z"),
    (ctx.str_concat(ctx.literal("x"), ctx.str_from_int(ctx.int(42))), "x42"),
    (ctx.str_from_int(ctx.int(-1)), ""),
  ]
  for entry in cases {
    assert_eq(ctx.eval(entry.0, empty), Text(entry.1))
  }
  let numbers : Array[(@smtlib.Term, Int32)] = [
    (ctx.str_index_of(text, ctx.literal("😀"), ctx.int(0)), 1),
    (ctx.str_index_of(text, ctx.literal("😀"), ctx.int(2)), 3),
    (ctx.str_index_of(text, ctx.literal("😀"), ctx.int(4)), -1),
    (ctx.str_index_of(text, ctx.literal(""), ctx.int(5)), 5),
    (ctx.str_index_of(text, ctx.literal(""), ctx.int(6)), -1),
    (ctx.str_index_of(text, ctx.literal("z"), ctx.int(-1)), -1),
    (ctx.str_to_int(ctx.literal("0042")), 42),
    (ctx.str_to_int(ctx.literal("")), -1),
    (ctx.str_to_int(ctx.literal("-1")), -1),
    (ctx.str_to_int(ctx.literal("４")), -1),
  ]
  for entry in numbers {
    assert_eq(
      ctx.eval(entry.0, empty),
      Integer(@bigint.BigInt::from_int(entry.1)),
    )
  }
  let facts : Array[(@smtlib.Term, Bool)] = [
    (ctx.str_contains(text, ctx.literal("é😀")), true),
    (ctx.str_contains(text, ctx.literal("éz")), false),
    (ctx.str_prefix_of(ctx.literal("A😀"), text), true),
    (ctx.str_prefix_of(text, ctx.literal("A😀")), false),
    (ctx.str_suffix_of(ctx.literal("😀z"), text), true),
    (ctx.str_lt(ctx.literal("a"), ctx.literal("ab")), true),
    (ctx.str_lt(ctx.literal("ab"), ctx.literal("ab")), false),
    (ctx.str_le(ctx.literal("ab"), ctx.literal("ab")), true),
    // Code point order: U+FFFD sorts below U+1F600, unlike UTF-16 units.
    (ctx.str_lt(ctx.literal("\u{FFFD}"), ctx.literal("😀")), true),
    (ctx.str_lt(ctx.literal("😀"), ctx.literal("\u{FFFD}")), false),
  ]
  for entry in facts {
    assert_eq(ctx.eval(entry.0, empty), Boolean(entry.1))
  }
  let invalid = try {
    ignore(ctx.string(String::from_array(['\u{30000}'])))
    false
  } catch {
    Unsupported(_) => true
    _ => false
  }
  assert_true(invalid)
}

///|
test "floating-point terms compute native Float and Double results" {
  let ctx = @smtlib.Context::new()
  let random : Random = { state: 0xfeed_face_cafe_beefUL, }
  let empty = @smtlib.Model::new()
  for _ in 0..<1000 {
    let x = random.word().reinterpret_as_double()
    let y = random.word().reinterpret_as_double()
    let (a, b) = (ctx.literal(x), ctx.literal(y))
    assert_eq(ctx.eval(ctx.fp_add(a, b), empty), @smtlib.Value::float64(x + y))
    assert_eq(ctx.eval(ctx.fp_sub(a, b), empty), @smtlib.Value::float64(x - y))
    assert_eq(ctx.eval(ctx.fp_mul(a, b), empty), @smtlib.Value::float64(x * y))
    assert_eq(ctx.eval(ctx.fp_div(a, b), empty), @smtlib.Value::float64(x / y))
    assert_eq(ctx.eval(ctx.fp_sqrt(a), empty), @smtlib.Value::float64(x.sqrt()))
    assert_eq(ctx.eval(ctx.fp_lt(a, b), empty), Boolean(x < y))
    assert_eq(ctx.eval(ctx.fp_le(a, b), empty), Boolean(x <= y))
    assert_eq(ctx.eval(ctx.fp_eq(a, b), empty), Boolean(x == y))
    assert_eq(ctx.eval(ctx.fp_is_nan(a), empty), Boolean(x.is_nan()))
    let p = Float::reinterpret_from_uint(random.word().to_uint())
    let q = Float::reinterpret_from_uint(random.word().to_uint())
    let (c, d) = (ctx.literal(p), ctx.literal(q))
    assert_eq(ctx.eval(ctx.fp_add(c, d), empty), @smtlib.Value::float32(p + q))
    assert_eq(ctx.eval(ctx.fp_mul(c, d), empty), @smtlib.Value::float32(p * q))
    assert_eq(ctx.eval(ctx.fp_div(c, d), empty), @smtlib.Value::float32(p / q))
    assert_eq(ctx.eval(ctx.fp_sqrt(c), empty), @smtlib.Value::float32(p.sqrt()))
    assert_eq(ctx.eval(ctx.fp_lt(c, d), empty), Boolean(p < q))
    assert_eq(
      ctx.eval(ctx.fp_convert(c, to=Float64), empty),
      @smtlib.Value::float64(p.to_double()),
    )
    assert_eq(
      ctx.eval(ctx.fp_convert(a, to=Float32), empty),
      @smtlib.Value::float32(Float::from_double(x)),
    )
  }
  let nan = ctx.literal(@double.not_a_number)
  let zero = ctx.literal(0.0)
  let negative_zero = ctx.fp_neg(zero)
  // `=` identifies NaN with itself and separates the zeros; fp.eq is IEEE.
  assert_eq(ctx.eval(ctx.eq(nan, nan), empty), Boolean(true))
  assert_eq(ctx.eval(ctx.fp_eq(nan, nan), empty), Boolean(false))
  assert_eq(ctx.eval(ctx.eq(zero, negative_zero), empty), Boolean(false))
  assert_eq(ctx.eval(ctx.fp_eq(zero, negative_zero), empty), Boolean(true))
  assert_eq(ctx.eval(ctx.fp_is_zero(negative_zero), empty), Boolean(true))
  assert_eq(ctx.eval(ctx.fp_neg(nan), empty), ctx.eval(nan, empty))
  assert_eq(
    ctx.eval(ctx.fp_is_infinite(ctx.fp_div(ctx.literal(1.0), zero)), empty),
    Boolean(true),
  )
  // Every NaN bit pattern denotes the one SMT NaN.
  assert_eq(
    ctx.eval(ctx.fp_from_bits(ctx.literal(0xfff0_0000_0000_0001UL)), empty),
    ctx.eval(nan, empty),
  )
  assert_eq(
    ctx.eval(ctx.fp_abs(ctx.literal((-2.5 : Float))), empty),
    @smtlib.Value::float32(2.5),
  )
}

///|
test "arrays model FixedArray cells and finite maps" {
  let ctx = @smtlib.Context::new()
  let cells : FixedArray[UInt32] = [10U, 20U, 0U, 40U]
  let value = @smtlib.array_value(cells[:], default=0U)
  let back : FixedArray[UInt32]? = value.to_fixed_array(4)
  assert_eq(back, Some(cells))
  let wrong : FixedArray[Bool]? = value.to_fixed_array(4)
  assert_eq(wrong, None)
  let array = ctx.value(value)
  inspect(
    ctx.to_smtlib(array),
    content="(store (store (store ((as const (Array Int (_ BitVec 32))) #x00000000) 0 #x0000000a) 1 #x00000014) 3 #x00000028)",
  )
  let i = ctx.constant("i", Int)
  let model = @smtlib.Model::new()
  for index, cell in cells {
    model.set("i", Integer(@bigint.BigInt::from_int(index)))
    assert_eq((ctx.eval_as(ctx.select(array, i), model) : UInt32), cell)
  }
  // Read after write, other keys unchanged, and writing back is the identity.
  let written = ctx.store(array, ctx.int(2), ctx.literal(30U))
  assert_eq((value_of(ctx, ctx.select(written, ctx.int(2))) : UInt32), 30U)
  assert_eq((value_of(ctx, ctx.select(written, ctx.int(3))) : UInt32), 40U)
  assert_eq((value_of(ctx, ctx.select(written, ctx.int(99))) : UInt32), 0U)
  let restored = ctx.store(written, ctx.int(2), ctx.literal(0U))
  assert_eq((value_of(ctx, ctx.eq(restored, array)) : Bool), true)
  assert_eq((value_of(ctx, ctx.eq(written, array)) : Bool), false)
  // Extensional equality over a finite index sort ignores the default.
  let on = ctx.const_array(Bool, ctx.int(1))
  let off = ctx.store(
    ctx.store(ctx.const_array(Bool, ctx.int(0)), ctx.bool(true), ctx.int(1)),
    ctx.bool(false),
    ctx.int(1),
  )
  assert_eq((value_of(ctx, ctx.eq(on, off)) : Bool), true)
  let ages : Map[String, Int32] = { "ada": 36, "alan": 41 }
  let table = @smtlib.map_value(ages, default=-1)
  let known : Int32? = table.lookup("alan")
  let unknown : Int32? = table.lookup("grace")
  assert_eq(known, Some(41))
  assert_eq(unknown, Some(-1))
  let term = ctx.value(table)
  assert_eq((value_of(ctx, ctx.select(term, ctx.literal("ada"))) : Int32), 36)
}

///|
test "ill-sorted terms and reserved names are rejected when built" {
  let ctx = @smtlib.Context::new()
  let x = ctx.constant("x", BitVec(8))
  let n = ctx.constant("n", Int)
  let attempts : Array[() -> @smtlib.Term raise @smtlib.SmtError] = [
    () => ctx.bv_add(x, n),
    () => ctx.bv_add(x, ctx.bv(16, 0UL)),
    () => ctx.int_add(x, n),
    () => ctx.and_(x, x),
    () => ctx.eq(x, n),
    () => ctx.ite(n, x, x),
    () => ctx.ite(ctx.bool(true), x, n),
    () => ctx.select(x, n),
    () => ctx.bv(65, 0UL),
    () => ctx.bv(0, 0UL),
    () => ctx.bv_extract(x, high=8, low=0),
    () => ctx.bv_zero_extend(x, width=4),
    () => ctx.bv_concat(ctx.literal(1UL), x),
    () => ctx.fp_from_bits(x),
    () => ctx.constant("x", Int),
    () => ctx.constant("", Int),
    () => ctx.constant("9lives", Int),
    () => ctx.constant("has space", Int),
    () => ctx.constant("$t1", Int),
    () => ctx.constant("select", Int),
    () => ctx.constant("wide", BitVec(128)),
  ]
  for index, attempt in attempts {
    let rejected = try {
      ignore(attempt())
      false
    } catch {
      _ => true
    }
    assert_true(rejected, msg="attempt \{index}")
  }
  assert_eq(ctx.constant("x", BitVec(8)), x)
  assert_eq(ctx.lookup("n"), Some(n))
  assert_eq(ctx.name_of(n), Some("n"))
  let script = @smtlib.Script::new(ctx)
  let rejected = try {
    script.assert_term(x)
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}

///|
test "deep and heavily shared terms stay linear" {
  let ctx = @smtlib.Context::new()
  let x : @smtlib.Typed[UInt64] = ctx.typed("x")
  // Each round uses the previous term three times: a tree of 3^64 nodes.
  let mut term = x.term
  for round in 0..<64 {
    let shifted = ctx.bv_shl(term, ctx.literal((round % 13 + 1).to_uint64()))
    term = ctx.bv_add(ctx.bv_xor(term, shifted), term)
  }
  assert_eq(ctx.dag_size(term), 206)
  assert_true(ctx.to_smtlib(term).length() < 6000)
  let model = @smtlib.Model::new()
  model.bind(x, 0x0123_4567_89ab_cdefUL)
  let mut expected = 0x0123_4567_89ab_cdefUL
  for round in 0..<64 {
    expected = (expected ^ (expected << (round % 13 + 1))) + expected
  }
  assert_eq((ctx.eval_as(term, model) : UInt64), expected)
  // A 100,000-deep chain is printed and evaluated without recursion.
  let mut chain = x.term
  for index in 0..<100000 {
    chain = ctx.bv_sub(ctx.literal(index.to_uint64()), chain)
  }
  let mut value = 0x0123_4567_89ab_cdefUL
  for index in 0..<100000 {
    value = index.to_uint64() - value
  }
  assert_eq((ctx.eval_as(chain, model) : UInt64), value)
  assert_true(ctx.to_smtlib(chain).length() > 2_000_000)
  assert_eq(ctx.free_constants(chain), [x.term])
}
