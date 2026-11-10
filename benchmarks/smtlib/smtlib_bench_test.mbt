///|
/// One timed implementation of a workload. The result is kept so the
/// optimizer cannot discard the work.
priv struct Variant {
  name : String
  run : () -> Int32
}

///|
priv struct Workload {
  name : String
  variants : Array[Variant]
}

///|
/// Two implementations with identical output. The outputs are compared here,
/// on the optimized backend being measured, before any timing.
fn Workload::compare(
  name : String,
  reference : () -> String,
  tuned : () -> String,
  timed_reference? : () -> Int32,
  timed_tuned? : () -> Int32,
) -> Workload {
  let expected = reference()
  guard tuned() == expected && !expected.is_empty() else {
    abort("Tuned output differs from the reference: " + name)
  }
  {
    name,
    variants: [
      {
        name: "reference",
        run: timed_reference.unwrap_or(() => materialize(reference())),
      },
      { name: "tuned", run: timed_tuned.unwrap_or(() => materialize(tuned())), },
    ],
  }
}

///|
/// Read the last code unit. A JavaScript engine represents concatenation
/// results as ropes whose length is known without building the text; indexing
/// forces the flat string a solver would actually be sent.
fn materialize(text : String) -> Int32 {
  text.length() + text.unsafe_get(text.length() - 1).to_int()
}

///|
fn Workload::single(name : String, run : () -> Int32) -> Workload {
  { name, variants: [{ name: "tuned", run, }], }
}

///|
/// The FNV-1a hash of `bytes` unknown bytes, constrained to a target: a
/// left-deep term of 3 * bytes + 2 operator nodes with no sharing.
fn checksum(ctx : @smt.Context, bytes : Int32) -> @smt.Term raise @smt.SmtError {
  let prime = ctx.bv(32, 0x0100_0193UL)
  let mut hash = ctx.bv(32, 0x811c_9dc5UL)
  for index in 0..<bytes {
    let byte = ctx.constant("b\{index}", BitVec(8))
    hash = ctx.bv_mul(
      ctx.bv_xor(hash, ctx.bv_zero_extend(byte, width=32)),
      prime,
    )
  }
  ctx.eq(hash, ctx.bv(32, 0xdead_beefUL))
}

///|
fn checksum_script(bytes : Int32) -> String {
  must(() => {
    let ctx = @smt.Context::new()
    let script = @smt.Script::new(ctx)
    script.assert_term(checksum(ctx, bytes))
    script.to_string()
  })
}

///|
/// The same script by nested string concatenation, the way a term builder
/// over strings composes subterms: each level copies everything below it.
fn checksum_concat(bytes : Int32) -> String {
  let declarations = []
  let mut hash = "#x811c9dc5"
  for index in 0..<bytes {
    declarations.push("(declare-const b\{index} (_ BitVec 8))\n")
    hash = "(bvmul (bvxor " +
      hash +
      " ((_ zero_extend 24) b\{index})) #x01000193)"
  }
  declarations.join("") + "(assert (= " + hash + " #xdeadbeef))\n"
}

///|
/// Each round uses the previous term three times, so the tree has 3^rounds
/// leaves while the term has 3 * rounds + 1 distinct nodes.
fn mixer(ctx : @smt.Context, rounds : Int32) -> @smt.Term raise @smt.SmtError {
  let mut term = ctx.constant("x", BitVec(64))
  for round in 0..<rounds {
    let shifted = ctx.bv_shl(term, ctx.bv(64, (round % 13 + 1).to_uint64()))
    term = ctx.bv_add(ctx.bv_xor(term, shifted), term)
  }
  term
}

///|
fn mixer_tree(rounds : Int32) -> String {
  let mut term = "x"
  for round in 0..<rounds {
    let count = (round % 13 + 1).to_string()
    let literal = "#x" + String::make(16 - count.length(), '0') + count
    term = "(bvadd (bvxor " +
      term +
      " (bvshl " +
      term +
      " " +
      literal +
      ")) " +
      term +
      ")"
  }
  term
}

///|
/// A `get-value` answer of mixed sorts with one binding per line.
fn values_fixture(
  ctx : @smt.Context,
  bindings : Int32,
) -> (String, Array[@smt.Term]) raise @smt.SmtError {
  let out = StringBuilder()
  let terms = []
  out.write_string("(")
  for index in 0..<bindings {
    let name = "v\{index}"
    out.write_string(if index == 0 { "(" } else { "\n (" })
    out.write_string(name)
    out.write_string(" ")
    match index % 5 {
      0 => {
        terms.push(ctx.constant(name, BitVec(32)))
        out.write_string(
          @smt.to_value((index * 2654435).reinterpret_as_uint()).to_smtlib(),
        )
      }
      1 => {
        terms.push(ctx.constant(name, Int))
        out.write_string("(- \{index * 7919})")
      }
      2 => {
        terms.push(ctx.constant(name, String))
        out.write_string("\"row \{index} \\u{1f600} \"\"quoted\"\"\"")
      }
      3 => {
        terms.push(ctx.constant(name, Bool))
        out.write_string(if index % 2 == 0 { "true" } else { "false" })
      }
      _ => {
        terms.push(ctx.constant(name, Array(Int, BitVec(8))))
        out.write_string(
          "(store (store ((as const (Array Int (_ BitVec 8))) #x00) \{index} #x\{index % 9}f) 0 #x01)",
        )
      }
    }
    out.write_string(")")
  }
  out.write_string(")")
  (out.to_string(), terms)
}

///|
fn smtlib_workloads() -> Array[Workload] {
  let workloads = []
  for bytes in [256, 2048] {
    workloads.push(
      Workload::compare(
        "smtlib/build-and-print|terms=\{3 * bytes + 2}",
        () => checksum_concat(bytes),
        () => checksum_script(bytes),
      ),
    )
  }
  // Sharing: the tuned text is linear in the rounds, the tree exponential.
  let rounds = 10
  let tree = mixer_tree(rounds)
  let shared = must(() => {
    let ctx = @smt.Context::new()
    ctx.to_smtlib(mixer(ctx, rounds))
  })
  guard shared.length() * 100 < tree.length() else {
    abort("Shared printing should be far smaller than the tree")
  }
  workloads.push({
    name: "smtlib/print-shared|rounds=\{rounds}",
    variants: [
      { name: "reference", run: () => materialize(mixer_tree(rounds)), },
      {
        name: "tuned",
        run: () => {
          must(() => {
            let ctx = @smt.Context::new()
            materialize(ctx.to_smtlib(mixer(ctx, rounds)))
          })
        },
      },
    ],
  })
  for bytes in [2048] {
    // Hash-consing: building an existing term again allocates no node.
    let ctx = @smt.Context::new()
    let first = must(() => checksum(ctx, bytes))
    let size = ctx.term_count()
    workloads.push(
      Workload::single("smtlib/rebuild-interned|terms=\{3 * bytes + 2}", () => {
        let again = must(() => checksum(ctx, bytes))
        guard again == first && ctx.term_count() == size else {
          abort("Rebuilding must return the interned term")
        }
        ctx.term_count()
      }),
    )
    workloads.push(
      Workload::single("smtlib/print|terms=\{3 * bytes + 2}", () => {
        materialize(ctx.to_smtlib(first))
      }),
    )
    // Evaluation on runtime bytes, checked against the native computation.
    let model = @smt.Model::new()
    let mut expected = 0x811c_9dc5U
    for index in 0..<bytes {
      let byte = (index * 31 + 7).to_byte()
      model.set("b\{index}", must(() => @smt.to_value(byte)))
      expected = (expected ^ byte.to_uint()) * 0x0100_0193U
    }
    guard must(() => ctx.eval(first, model)) ==
      Boolean(expected == 0xdead_beefU) else {
      abort("Evaluation disagrees with the native checksum")
    }
    workloads.push(
      Workload::single("smtlib/eval|terms=\{3 * bytes + 2}", () => {
        match must(() => ctx.eval(first, model)) {
          Boolean(true) => 1
          _ => 0
        }
      }),
    )
  }
  for bindings in [256, 2048] {
    let ctx = @smt.Context::new()
    let (text, terms) = must(() => values_fixture(ctx, bindings))
    guard must(() => ctx.parse_values(text, terms)).length() == bindings else {
      abort("Fixture must decode completely")
    }
    workloads.push(
      Workload::single("smtlib/parse-values|bindings=\{bindings}", () => {
        must(() => ctx.parse_values(text, terms)).length()
      }),
    )
  }
  // FixedArray cells to an SMT array value and back.
  let cells : FixedArray[UInt32] = FixedArray::makei(2048, i => {
    (i * 2654435).reinterpret_as_uint()
  })
  workloads.push(
    Workload::single("smtlib/array-roundtrip|cells=2048", () => {
      must(() => {
        let value = @smt.array_value(cells[:], default=0U)
        let back : FixedArray[UInt32]? = value.to_fixed_array(cells.length())
        guard back is Some(back) && back[2047] == cells[2047] else {
          abort("Array cells must survive the roundtrip")
        }
        back.length()
      })
    }),
  )
  workloads
}

///|
/// Two passes reverse the variant order; each has five timed batches.
fn measure(b : @bench.Bench, workloads : Array[Workload]) -> Unit {
  for workload in workloads {
    for pass in 0..<2 {
      let variants = if pass == 0 {
        workload.variants
      } else {
        workload.variants.rev()
      }
      for variant in variants {
        b.bench(
          name="\{workload.name}|\{variant.name}|pass=\{pass}",
          () => b.keep((variant.run)()),
          count=5,
        )
      }
    }
  }
  // Stable envelope; retain the upstream numeric summary without table rounding.
  println("VERI_BENCH_JSON " + b.dump_summaries())
}

///|
test "model_check encoding against the reference" (b : @bench.T) {
  measure(b, model_check_workloads())
}

///|
test "smtlib terms, values and evaluation" (b : @bench.T) {
  measure(b, smtlib_workloads())
}
