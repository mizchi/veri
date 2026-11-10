///|
test "terms print as SMT-LIB 2 and share repeated subterms" {
  let ctx = @smtlib.Context::new()
  let x = ctx.constant("x", BitVec(32))
  let y = ctx.constant("y", BitVec(32))
  let sum = ctx.bv_add(x, y)
  // Hash-consing: the same structure is the same handle.
  assert_eq(sum, ctx.bv_add(x, y))
  assert_true(sum != ctx.bv_add(y, x))
  inspect(ctx.to_smtlib(sum), content="(bvadd x y)")
  let twice = ctx.bv_mul(sum, sum)
  inspect(
    ctx.to_smtlib(ctx.eq(twice, ctx.bv(32, 9UL))),
    content="(let (($t2 (bvadd x y))) (= (bvmul $t2 $t2) #x00000009))",
  )
  inspect(ctx.dag_size(twice), content="4")
  let flags = [ctx.constant("p", Bool), ctx.constant("q", Bool), ctx.bool(true)]
  inspect(ctx.to_smtlib(ctx.all(flags)), content="(and p q true)")
  inspect(ctx.to_smtlib(ctx.any([])), content="false")
  inspect(
    ctx.to_smtlib(
      ctx.bv_extract(ctx.bv_zero_extend(x, width=64), high=39, low=8),
    ),
    content="((_ extract 39 8) ((_ zero_extend 32) x))",
  )
  inspect(ctx.to_smtlib(ctx.int(-3)), content="(- 3)")
  inspect(ctx.to_smtlib(ctx.bv(5, 0xffUL)), content="#b11111")
  inspect(
    ctx.to_smtlib(ctx.string("a\"b\\n\u{1F600}\n")),
    content=(
      #|"a""b\u{5c}n\u{1f600}\u{a}"
    ),
  )
  inspect(
    ctx.to_smtlib(ctx.const_array(Int, ctx.float64(1.5))),
    content="((as const (Array Int (_ FloatingPoint 11 53))) (fp #b0 #b01111111111 #x8000000000000))",
  )
  inspect(
    ctx.to_smtlib(ctx.float32(-0.0)),
    content="(fp #b1 #x00 #b00000000000000000000000)",
  )
}

///|
test "scripts declare constants once per solver scope" {
  let ctx = @smtlib.Context::new()
  let x : @smtlib.Typed[UInt32] = ctx.typed("x")
  let n = ctx.constant("n", Int)
  let script = @smtlib.Script::new(ctx, logic="ALL")
  script.assert_term(ctx.bv_ult(x.term, ctx.literal(10U)))
  script.push()
  script.assert_term(ctx.int_lt(n, ctx.int(0)))
  script.assert_term(ctx.int_lt(n, ctx.int(1)))
  script.check_sat()
  script.pop()
  script.assert_term(ctx.int_gt(n, ctx.int(0)))
  script.get_value([x.term, n])
  inspect(
    script.to_string(),
    content=(
      #|(set-logic ALL)
      #|(declare-const x (_ BitVec 32))
      #|(assert (bvult x #x0000000a))
      #|(push 1)
      #|(declare-const n Int)
      #|(assert (< n 0))
      #|(assert (< n 1))
      #|(check-sat)
      #|(pop 1)
      #|(declare-const n Int)
      #|(assert (< 0 n))
      #|(get-value (x n))
      #|
    ),
  )
}

///|
test "evaluation runs on runtime values" {
  let ctx = @smtlib.Context::new()
  let x : @smtlib.Typed[UInt32] = ctx.typed("x")
  let y : @smtlib.Typed[UInt32] = ctx.typed("y")
  let model = @smtlib.Model::new()
  model.bind(x, 0xffff_fff0U)
  model.bind(y, 0x20U)
  let sum : UInt32 = ctx.eval_as(ctx.bv_add(x.term, y.term), model)
  assert_eq(sum, 0x10U)
  assert_eq(sum, @uint32.add(0xffff_fff0U, 0x20U))
  let below : Bool = ctx.eval_as(ctx.bv_ult(x.term, y.term), model)
  assert_eq(below, @uint32.less(0xffff_fff0U, 0x20U))
  assert_eq(model.read(x), Some(0xffff_fff0U))
}
