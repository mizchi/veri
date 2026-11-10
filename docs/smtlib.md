# SMT-LIB 2 terms and runtime values

[日本語](smtlib.ja.md) | [README](../README.md)

`mizchi/veri/smtlib` builds, prints, parses and evaluates SMT-LIB 2 terms, and
maps MoonBit runtime values to SMT values in both directions. It complements
the proof bindings: `bitvector`, `arrays`, `strings` and `ieee754` name these
theories for `moon prove`, while `smtlib` makes the same theories available
as ordinary runtime data.

```text
runtime value ──Encode──▶ Value ──▶ Term in a Context ──Script──▶ solver
      ▲                     ▲            │ eval                      │
      └────── decode ───────┴────────────┴── parse_values / parse_model
```

It runs on every backend and depends on nothing outside this module.
`mizchi/veri/smtlib/solver` adds a solver process and therefore supports the
native and wasm backends only.

## Sorts and runtime types

| Sort | `Value` | Runtime type through `Encode` |
| --- | --- | --- |
| `Bool` | `Boolean` | `Bool` |
| `Int` | `Integer` | `BigInt` |
| `(_ BitVec n)`, `1 <= n <= 64` | `Bits(n, bits)` | `Byte` (8), `UInt16` (16), `UInt` / `Int` (32), `UInt64` / `Int64` (64) |
| `String` | `Text` | `String`, well-formed UTF-16 within U+0000..U+2FFFF |
| `(_ FloatingPoint 8 24)` / `11 53` | `F32` / `F64` | `Float` / `Double` |
| `(Array K V)` | `Table` | `array_value` for cells, `map_value` for `Map[K, V]` |

Machine integers are bitvectors of their width, so a term over `UInt` wraps
exactly as the runtime does. This is the encoding `runtime/uint32.model` and
`runtime/uint64.model` use in proofs. `Int` and `UInt` share the same 32 bits:
signedness belongs to the operation (`bv_slt` or `bv_ult`), not to the value.
Use `BigInt` for the unbounded `Int` sort.

Floats are IEEE bit patterns with every NaN canonicalized, because SMT-LIB has
a single NaN. An array value is total: `array_value(cells, default~)` stores
`cells` at indices `0..cells.length()` and `default` everywhere else, and only
that first range denotes runtime cells, the convention of `runtime/array.model`.
`Value::to_fixed_array(length)` reads the range back.

## Building and evaluating terms

Terms live in a `Context`. Every constructor checks operand sorts and raises
`SortMismatch`, so an ill-sorted script is rejected before a solver sees it.
`examples/midpoint` contains the complete example.

```moonbit
// Import mizchi/veri/smtlib.
test {
  let ctx = @smtlib.Context::new()
  let low : @smtlib.Typed[UInt] = ctx.typed("low")
  let high : @smtlib.Typed[UInt] = ctx.typed("high")
  // (low + high) / 2 over (_ BitVec 32)
  let middle = ctx.bv_udiv(ctx.bv_add(low.term, high.term), ctx.literal(2U))

  let inputs = @smtlib.Model::new()
  inputs.bind(low, 0xf000_0000U)
  inputs.bind(high, 0xffff_ffffU)
  let value : UInt = ctx.eval_as(middle, inputs)
  assert_eq(value, (0xf000_0000U + 0xffff_ffffU) / 2U) // both wrap to 0x77ffffff
}
```

Terms are hash-consed: building the same structure twice returns the same
handle, `==` on terms is an integer comparison, and a subterm used several
times is printed once under `let`. Traversals use explicit stacks, so a term
100,000 levels deep is printed and evaluated without recursion.

`Context::eval` follows SMT-LIB 2 rather than machine behavior where they differ:

| Operation | Result |
| --- | --- |
| `bv_udiv` / `bv_urem` by zero | All ones / the dividend |
| `bv_sdiv` of the minimum by -1 | The minimum |
| Shifts by at least the width | Zero, or the sign fill for `bv_ashr` |
| `int_div` / `int_mod` | Euclidean, remainder never negative; by zero `Unspecified` |
| String positions and lengths | Code points, not UTF-16 units |
| `eq` on floats | `NaN = NaN`, `+0 ≠ -0`; `fp_eq` is IEEE equality |
| Float arithmetic | Round to nearest, ties to even |

`Unspecified` is raised when the result depends on integer division by zero or
on a constant missing from the model, unless `and`, `or`, `=>` or `ite` decide
the result from their other operands.

## Scripts and solver answers

`Script` writes commands. Constants are declared automatically before their
first use, and `push` / `pop` retract those declarations along with the solver's.

```moonbit
// claim: `low <= high` implies `low <= middle <= high`, built with bv_ule / and_ / implies
let script = @smtlib.Script::new(ctx, logic="QF_BV")
script.assert_term(ctx.not_(claim))
script.check_sat()
script.get_value([low.term, high.term])
// script.to_string():
// (set-logic QF_BV)
// (declare-const low (_ BitVec 32))
// (declare-const high (_ BitVec 32))
// (assert (let (($t4 (bvudiv (bvadd low high) #x00000002)))
//   (not (=> (bvule low high) (and (bvule low $t4) (bvule $t4 high))))))
// (check-sat)
// (get-value (low high))

let values = ctx.parse_values("((low #xf0000000)\n (high #xffffffff))", [low.term, high.term])
let found : UInt? = values[0].decode() // Some(0xf0000000)
```

`parse_values` decodes a `get-value` answer by the sort of each requested
term, and `parse_model` a `get-model` answer. Both accept what Z3 prints:
`#x` / `#b` / `(_ bvN w)` literals, `(- n)`, string escapes, `(fp ...)` and the
named float constants, arrays as `store` chains over `as const`, values
abbreviated with `let`, and arrays printed as a `lambda` that is a case split
on `(= x literal)`. Anything else raises `Malformed` or `Unsupported`; a model
is never partially decoded.

With a solver on PATH, `smtlib/solver` runs the query (native and wasm):

```moonbit
// Import mizchi/veri/smtlib/solver.
async fn find_inverse() -> UInt {
  let ctx = @smtlib.Context::new()
  let x : @smtlib.Typed[UInt] = ctx.typed("x")
  let inverse = ctx.eq(ctx.bv_mul(x.term, ctx.literal(0x9e37_79b1U)), ctx.literal(1U))
  guard @solver.check(ctx, [inverse]) is Satisfiable(model) else { abort("no inverse") }
  model.read(x).unwrap() // multiplying it by 0x9e3779b1 gives 1 natively
}
```

`with_session` keeps one process for incremental use: `Session::check_sat`,
`Session::values`, and `Session::send` / `line` / `response` for raw commands.
Timeouts, memory and input/output budgets are enforced, and the process is
killed when the callback fails. The model checker's runner uses the same session.

## Names shared with the proof bindings

| Proof binding (Why3) | `smtlib` term | SMT-LIB 2 |
| --- | --- | --- |
| `Bv32::add/sub/mul/udiv/urem/sdiv/srem` | `bv_add` … `bv_srem` | `bvadd` … `bvsrem` |
| `Bv32::bw_and/bw_or/bw_xor/bw_not`, `neg` | `bv_and/bv_or/bv_xor/bv_not`, `bv_neg` | `bvand` … `bvneg` |
| `Bv32::shl/lshr/ashr`, `ult/ule/slt/sle` | `bv_shl` … `bv_sle` | `bvshl` … `bvsle` |
| `to_bv8` … `to_bv64` | `bv_extract`, `bv_zero_extend`, `bv_sign_extend`, `bv_concat` | `extract`, `zero_extend`, `sign_extend`, `concat` |
| `of_integer` / `to_integer` | `int_to_bv` / `bv_to_int` | `int2bv` / `bv2nat` |
| `arrays.select/store/const_array` | `select` / `store` / `const_array` | `select` / `store` / `as const` |
| `strings.concat/length/char_at/substring` | `str_concat/str_length/str_at/str_substr` | `str.++`, `str.len`, `str.at`, `str.substr` |
| `strings.contains/prefix_of/suffix_of/index_of/replace` | `str_contains` … `str_replace` | `str.contains` … `str.replace` |
| `strings.to_integer/from_integer/lt/le` | `str_to_int/str_from_int/str_lt/str_le` | `str.to_int`, `str.from_int`, `str.<`, `str.<=` |

The proof bindings and `smtlib` are separate: a `Term` is not a proof-level
`Bv32`, and nothing here is assumed by `moon prove`.

## What is checked

- Unit tests on all four backends compare evaluation with native `UInt`, `Int`,
  `UInt64`, `Int64`, `Byte`, `Float` and `Double` operators on boundary-biased
  random inputs, and with the proved `runtime/uint32` and `runtime/uint64`
  `add` / `sub` / `less` adapters.
- `just smtlib` runs `cmd/smtlib-check` against Z3. It generates random
  well-sorted terms over every sort and operator. For closed terms it proves
  `term = value` (the negation is `unsat`). For terms with constants it defines
  the constants as random values, reads each term back with `get-value`, and
  compares with the interpreter. Six fixed queries are solved and their models
  confirmed with native operations. The default 200 rounds cover about 12,000
  terms; terms whose value SMT-LIB leaves unspecified are skipped and counted.
- The model-check encoder's output is pinned byte for byte by snapshots taken
  from the previous implementation.

## Limitations

- The fragment is quantifier-free without uninterpreted functions, reals,
  regular expressions, or bitvectors wider than 64 bits.
- Floating-point arithmetic is round-to-nearest-even only, and there is no
  term for the bits of a float (SMT-LIB has no such function).
- A string containing an unpaired surrogate, or a solver model that needs one,
  is rejected: MoonBit strings cannot represent it.
- The interpreter is differential-tested, not proved. Agreement with Z3 is
  evidence for the generated terms, not a theorem about all terms.
- Solver results are as trustworthy as the solver; `unknown` and timeouts
  decide nothing.

Timings and their limits are in the [benchmark guide](benchmarks.md#smt-lib-benchmarks).
