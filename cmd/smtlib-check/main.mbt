///|
/// Sorts at the root of generated terms, cycled so each is covered evenly.
fn root_sort(random : Random, index : Int32) -> @smtlib.Sort {
  match index % 8 {
    0 => Bool
    1 => Int
    2 => String
    3 => Float32
    4 => Float64
    5 => Array(random.index_sort(), random.scalar_sort())
    _ => BitVec(random.width())
  }
}

///|
priv struct Tally {
  mut closed : Int32
  mut open : Int32
  mut skipped : Int32
}

///|
/// Closed terms: the interpreter's value must be the only possible one, so
/// "some term differs from its value" has to be unsatisfiable.
async fn check_closed(z3 : String, random : Random, tally : Tally) -> Unit {
  let ctx = @smtlib.Context::new()
  let generator : Generator = {
    ctx,
    random,
    model: @smtlib.Model::new(),
    variables: false,
    fresh: 0,
  }
  let claims : Array[(@smtlib.Term, @smtlib.Term)] = []
  for index in 0..<40 {
    let term = generator.term(root_sort(random, index), 3)
    let value = ctx.eval(term, generator.model) catch {
      Unspecified(_) => {
        tally.skipped += 1
        continue
      }
      error => raise error
    }
    claims.push((term, ctx.value(value)))
  }
  let differs = ctx.any(claims.map(claim => ctx.distinct(claim.0, claim.1)))
  if @solver.check(ctx, [differs], z3~, timeout_ms=120000) is Unsatisfiable {
    tally.closed += claims.length()
    return
  }
  // Report the first individual disagreement, in one incremental session.
  @solver.with_session(z3~, timeout_ms=120000, session => {
    let script = @smtlib.Script::new(ctx, logic="ALL")
    for claim in claims {
      script.push()
      script.assert_term(ctx.distinct(claim.0, claim.1))
      let status = session.check_sat(script)
      script.pop()
      if status != Unsat {
        println("Interpreter and solver disagree:")
        println("  term:  " + ctx.to_smtlib(claim.0))
        println("  value: " + ctx.to_smtlib(claim.1))
        abort("smtlib differential check failed")
      }
    }
  })
  abort("A batch was not unsat although each of its claims is")
}

///|
/// Terms with constants: define the constants as random values, name every
/// term, read the names back with get-value, and compare with the
/// interpreter evaluating under the same assignment.
async fn check_open(z3 : String, random : Random, tally : Tally) -> Unit {
  let ctx = @smtlib.Context::new()
  let model = @smtlib.Model::new()
  let generator : Generator = { ctx, random, model, variables: true, fresh: 0, }
  let terms : Array[@smtlib.Term] = []
  let expected : Array[@smtlib.Value] = []
  for index in 0..<20 {
    let term = generator.term(root_sort(random, index), 3)
    let value = ctx.eval(term, model) catch {
      Unspecified(_) => {
        tally.skipped += 1
        continue
      }
      error => raise error
    }
    terms.push(term)
    expected.push(value)
  }
  let script = @smtlib.Script::new(ctx, logic="ALL")
  // Constants are defined, not constrained: the solver then reduces every
  // term by rewriting, as it does for closed terms, instead of searching.
  for name in model.names() {
    let value = model.get(name).unwrap()
    script.define_constant(ctx.constant(name, value.sort()), ctx.value(value))
  }
  // Name each term: get-value on a constant always yields a literal, while
  // the model evaluator may leave a compound string term partly reduced.
  let results = terms.mapi((index, term) => {
    let result = ctx.constant("r\{index}", ctx.sort_of(term))
    script.assert_term(ctx.eq(result, term))
    result
  })
  let actual = @solver.with_session(z3~, timeout_ms=120000, session => {
    guard session.check_sat(script) == Sat else {
      abort("Naming the terms of defined constants was not satisfiable")
    }
    session.values(ctx, script, results)
  })
  for index, term in terms {
    if actual[index] != expected[index] {
      println("Interpreter and solver model disagree:")
      println("  term:        " + ctx.to_smtlib(term))
      println("  interpreter: " + expected[index].to_smtlib())
      println("  solver:      " + actual[index].to_smtlib())
      for name in ctx.free_constants(term).map(c => ctx.name_of(c).unwrap()) {
        println("  \{name} = " + model.get(name).unwrap().to_smtlib())
      }
      abort("smtlib differential check failed")
    }
  }
  tally.open += terms.length()
}

///|
/// Solve for runtime values and confirm them with native MoonBit operations.
async fn check_solved(z3 : String) -> Int32 {
  let ctx = @smtlib.Context::new()
  // A modular inverse: found over (_ BitVec 32), verified as UInt.
  let x : @smtlib.Typed[UInt32] = ctx.typed("x")
  let inverse = ctx.eq(
    ctx.bv_mul(x.term, ctx.literal(0x9e37_79b1U)),
    ctx.literal(1U),
  )
  guard @solver.check(ctx, [inverse], z3~) is Satisfiable(model) else {
    abort("Expected a modular inverse")
  }
  guard model.read(x) is Some(found) && found * 0x9e37_79b1U == 1U else {
    abort("The solver's inverse fails natively")
  }
  // A string equation, decoded into a MoonBit String.
  let s : @smtlib.Typed[String] = ctx.typed("s")
  let greeting = ctx.eq(
    ctx.str_concat(s.term, ctx.literal("😀!")),
    ctx.literal("hello😀!"),
  )
  guard @solver.check(ctx, [greeting], z3~) is Satisfiable(model) else {
    abort("Expected a string solution")
  }
  guard model.read(s) == Some("hello") else {
    abort("Unexpected string solution")
  }
  // Array cells read back as a FixedArray.
  let cells = ctx.constant("cells", Array(Int, BitVec(8)))
  let facts = [
    ctx.eq(ctx.select(cells, ctx.int(0)), ctx.literal(b'\x10')),
    ctx.eq(
      ctx.select(cells, ctx.int(1)),
      ctx.bv_add(ctx.select(cells, ctx.int(0)), ctx.literal(b'\xf8')),
    ),
    ctx.eq(
      ctx.select(cells, ctx.int(2)),
      ctx.bv_not(ctx.select(cells, ctx.int(1))),
    ),
  ]
  guard @solver.check(ctx, facts, z3~) is Satisfiable(model) else {
    abort("Expected an array model")
  }
  let bytes : FixedArray[Byte]? = model.get("cells").unwrap().to_fixed_array(3)
  guard bytes == Some([b'\x10', b'\x08', b'\xf7']) else {
    abort("Unexpected array model")
  }
  // The solver's model satisfies the assertions under the interpreter too.
  for fact in facts {
    guard ctx.eval(fact, model) == Boolean(true) else {
      abort("The interpreter rejects a solver model")
    }
  }
  // Absorption: a Double that adding one does not change.
  let d : @smtlib.Typed[Double] = ctx.typed("d")
  let absorbed = [
    ctx.eq(ctx.fp_add(d.term, ctx.literal(1.0)), d.term),
    ctx.fp_lt(ctx.literal(0.0), d.term),
    ctx.not_(ctx.fp_is_infinite(d.term)),
  ]
  guard @solver.check(ctx, absorbed, z3~) is Satisfiable(model) else {
    abort("Expected an absorbing Double")
  }
  guard model.read(d) is Some(large) && large + 1.0 == large && large > 0.0 else {
    abort("The solver's Double fails natively")
  }
  // One incremental session: scopes retract assertions and declarations.
  @solver.with_session(z3~, session => {
    let script = @smtlib.Script::new(ctx, logic="ALL")
    let n = ctx.constant("n", Int)
    script.assert_term(ctx.int_lt(ctx.int(10), n))
    script.push()
    let m = ctx.constant("m", Int)
    script.assert_term(ctx.int_lt(n, m))
    script.assert_term(ctx.int_lt(m, ctx.int(12)))
    guard session.check_sat(script) == Unsat else {
      abort("No integer lies strictly between 10 and 12 twice")
    }
    script.pop()
    script.assert_term(ctx.eq(m, ctx.int_mul(n, ctx.int(3))))
    guard session.check_sat(script) == Sat else {
      abort("The popped scope should no longer constrain m")
    }
    let values = session.values(ctx, script, [n, m])
    guard values is [Integer(first), Integer(second)] &&
      first > 10N &&
      second == first * 3N else {
      abort("Unexpected values after pop")
    }
  })
  // Commutativity of wrapping addition has no counterexample.
  let y : @smtlib.Typed[UInt32] = ctx.typed("y")
  let counterexample = ctx.distinct(
    ctx.bv_add(x.term, y.term),
    ctx.bv_add(y.term, x.term),
  )
  guard @solver.check(ctx, [counterexample], z3~) is Unsatisfiable else {
    abort("Wrapping addition should commute")
  }
  6
}

///|
/// Differential check of `mizchi/veri/smtlib` against a real solver.
/// Usage: smtlib-check [rounds] [seed] [z3]
async fn main {
  let args = @env.args()
  let rounds = if args.length() > 1 {
    @string.parse_int(args[1][:])
  } else {
    50
  }
  let seed = if args.length() > 2 {
    @string.parse_int(args[2][:])
  } else {
    2026
  }
  let z3 = if args.length() > 3 { args[3] } else { "z3" }
  let random : Random = {
    state: seed.to_uint64() * 0x9e37_79b9_7f4a_7c15UL + 1UL,
  }
  let tally : Tally = { closed: 0, open: 0, skipped: 0, }
  for _ in 0..<rounds {
    check_closed(z3, random, tally)
    check_open(z3, random, tally)
  }
  let solved = check_solved(z3)
  println(
    "smtlib: \{tally.closed} closed terms proved equal to their values, " +
    "\{tally.open} open terms matched solver models, " +
    "\{tally.skipped} skipped as unspecified, \{solved} solved queries verified natively " +
    "(rounds=\{rounds}, seed=\{seed})",
  )
}
