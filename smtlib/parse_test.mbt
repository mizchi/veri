///|
/// Output of Z3 4.16.0 for a script mixing every supported sort.
const Z3_VALUES : String =
  #|((a (store ((as const (Array Int (_ BitVec 8))) #x07) (- 2) #x09))
  #| (m (store ((as const (Array (_ BitVec 4) Bool)) true) #x4 false))
  #| (s "a""b\n\u{1f600}\u{a}")
  #| (f (_ NaN 8 24))
  #| (d (fp #b0 #b01111111111 #x8000000000000))
  #| (n (- 100000000000000000001))
  #| (b #b10101)
  #| (((_ to_fp 8 24) #x7f800000) (_ +oo 8 24))
  #| ((fp.neg ((_ to_fp 8 24) #x00000000)) (_ -zero 8 24)))

///|
const Z3_MODEL : String =
  #|(
  #|  (define-fun a () (Array Int (_ BitVec 8))
  #|    (store ((as const (Array Int (_ BitVec 8))) #x07) (- 2) #x09))
  #|  (define-fun n () Int
  #|    (- 100000000000000000001))
  #|  (define-fun f () (_ FloatingPoint 8 24)
  #|    (_ NaN 8 24))
  #|  (define-fun |quoted name| () (_ BitVec 5)
  #|    (_ bv21 5)) ; comment
  #|  (define-fun d () (_ FloatingPoint 11 53)
  #|    (fp #b0 #b01111111111 #x8000000000000))
  #|)

///|
test "get-value answers decode into runtime values" {
  let ctx = @smtlib.Context::new()
  let a = ctx.constant("a", Array(Int, BitVec(8)))
  let m = ctx.constant("m", Array(BitVec(4), Bool))
  let s : @smtlib.Typed[String] = ctx.typed("s")
  let f : @smtlib.Typed[Float] = ctx.typed("f")
  let d : @smtlib.Typed[Double] = ctx.typed("d")
  let n = ctx.constant("n", Int)
  let b = ctx.constant("b", BitVec(5))
  let infinity = ctx.fp_from_bits(ctx.bv(32, 0x7f80_0000UL))
  let negative_zero = ctx.fp_neg(ctx.fp_from_bits(ctx.bv(32, 0UL)))
  let terms = [a, m, s.term, f.term, d.term, n, b, infinity, negative_zero]
  let values = ctx.parse_values(Z3_VALUES, terms)
  let bytes : FixedArray[Byte]? = values[0].to_fixed_array(4)
  assert_eq(bytes, Some([b'\x07', b'\x07', b'\x07', b'\x07']))
  let minus_two : Byte? = values[0].lookup(-2N)
  assert_eq(minus_two, Some(b'\x09'))
  inspect(
    values[1].to_smtlib(),
    content="(store ((as const (Array (_ BitVec 4) Bool)) true) #x4 false)",
  )
  let text : String? = values[2].decode()
  assert_eq(text, Some("a\"b\\n\u{1F600}\n"))
  let single : Float? = values[3].decode()
  assert_true(single.unwrap().is_nan())
  let double : Double? = values[4].decode()
  assert_eq(double, Some(1.5))
  assert_eq(values[5], Integer(-100000000000000000001N))
  assert_eq(values[6], Bits(5, 21UL))
  assert_eq(values[7], @smtlib.Value::float32(@float.infinity))
  assert_eq(values[8], @smtlib.Value::float32(-0.0))
  // Solver values agree with the interpreter on closed terms.
  let empty = @smtlib.Model::new()
  assert_eq(ctx.eval(infinity, empty), values[7])
  assert_eq(ctx.eval(negative_zero, empty), values[8])
  // A decoded model is an assignment the interpreter accepts.
  let model = @smtlib.Model::new()
  model.set("a", values[0])
  model.set("b", values[6])
  let cell = ctx.select(a, ctx.int(-2))
  assert_eq(ctx.eval(cell, model), Bits(8, 9UL))
  ignore(m)
}

///|
test "get-model answers decode by declared sort" {
  let model = @smtlib.parse_model(Z3_MODEL)
  assert_eq(model.names(), ["a", "n", "f", "quoted name", "d"])
  assert_eq(model.get("quoted name"), Some(Bits(5, 21UL)))
  assert_eq(model.get("n"), Some(Integer(-100000000000000000001N)))
  assert_eq(model.get("d"), Some(@smtlib.Value::float64(1.5)))
  assert_eq(model.get("missing"), None)
}

///|
test "malformed or unsupported solver text is rejected" {
  let ctx = @smtlib.Context::new()
  let x = ctx.constant("x", BitVec(8))
  let n = ctx.constant("n", Int)
  let table = ctx.constant("t", Array(Int, Int))
  for
    entry in [
      ("((x #x07)", [x]),
      ("((x #x07)))", [x]),
      ("((x #x007))", [x]),
      ("((x #b0000011g))", [x]),
      ("((x (_ bv256 8)))", [x]),
      ("((x 7))", [x]),
      ("((n #x07))", [n]),
      ("((n 1) (x #x00))", [n]),
      ("((n 1x))", [n]),
      ("((n \"1\"))", [n]),
      ("((t (lambda ((i Int)) i)))", [table]),
      ("((t ((as const (Array Int Bool)) true)))", [table]),
      ("((t (_ as-array k!0)))", [table]),
      ("\"unterminated", [n]),
      ("|unterminated", [n]),
    ] {
    let rejected = try {
      ignore(ctx.parse_values(entry.0, entry.1))
      false
    } catch {
      _ => true
    }
    assert_true(rejected, msg=entry.0)
  }
  let rejected = try {
    ignore(@smtlib.parse_model("((define-fun f ((x Int)) Int x))"))
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}

///|
test "let-abbreviated and lambda array values decode" {
  let ctx = @smtlib.Context::new()
  let flags = ctx.constant("flags", Array(Bool, Bool))
  let table = ctx.constant("table", Array(Int, String))
  let bytes = ctx.constant("bytes", Array(BitVec(2), BitVec(8)))
  let values = ctx.parse_values(
    (
      #|((flags (lambda ((x!1 Bool)) (not x!1)))
      #| (table (let ((a!1 (store ((as const (Array Int String)) "") 7 "seven")))
      #|   (store a!1 (- 1) "minus")))
      #| (bytes (lambda ((i (_ BitVec 2))) (ite (or (= i #b01) (= #b11 i)) #xff #x00))))
    ),
    [flags, table, bytes],
  )
  let negated : Bool? = values[0].lookup(true)
  assert_eq(negated, Some(false))
  let kept : Bool? = values[0].lookup(false)
  assert_eq(kept, Some(true))
  let seven : String? = values[1].lookup(7N)
  let minus : String? = values[1].lookup(-1N)
  let other : String? = values[1].lookup(8N)
  assert_eq((seven, minus, other), (Some("seven"), Some("minus"), Some("")))
  assert_eq(
    values[2],
    Table(
      @smtlib.ArrayValue::constant(BitVec(2), Bits(8, 0UL))
      .store(Bits(2, 1UL), Bits(8, 0xffUL))
      .store(Bits(2, 3UL), Bits(8, 0xffUL)),
    ),
  )
  // Over an infinite index sort, the keys a case split mentions decide it.
  let sparse = ctx.parse_values(
    (
      #|((table (lambda ((k Int)) (ite (= k 3) "three" (ite (= k (- 4)) "four" "none")))))
    ),
    [table],
  )
  let three : String? = sparse[0].lookup(3N)
  let four : String? = sparse[0].lookup(-4N)
  let none : String? = sparse[0].lookup(0N)
  assert_eq((three, four, none), (Some("three"), Some("four"), Some("none")))
}

///|
test "string escapes follow SMT-LIB 2.6" {
  let sexps = @smtlib.parse_sexps(
    (
      #|"" "a""b" "\u{48}\u0049" "\u{1F600}" "\x41 \u{} \uD83 \u{110000"
    ),
  )
  let decoded = sexps.map(sexp => {
    match sexp {
      Str(text) => text
      _ => "?"
    }
  })
  assert_eq(decoded, [
    "", "a\"b", "HI", "\u{1F600}", "\\x41 \\u{} \\uD83 \\u{110000",
  ])
  // A lone surrogate is in the SMT alphabet but not a MoonBit string.
  let rejected = try {
    ignore(@smtlib.parse_sexps("\"\\u{d800}\""))
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}

///|
test "deeply nested output does not use the call stack" {
  let depth = 200000
  let out = StringBuilder()
  for _ in 0..<depth {
    out.write_string("(store ")
  }
  out.write_string("((as const (Array Int Int)) 0)")
  for index in 0..<depth {
    out.write_string(" \{index % 1000} \{index})")
  }
  let ctx = @smtlib.Context::new()
  let table = ctx.constant("t", Array(Int, Int))
  let values = ctx.parse_values("((t " + out.to_string() + "))", [table])
  let last : @bigint.BigInt? = values[0].lookup(999N)
  assert_eq(last, Some(199999N))
  guard values[0] is Table(array) else { fail("Expected an array value") }
  assert_eq(array.override_count(), 1000)
}
