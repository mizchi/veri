# veri

English | [日本語](README.ja.md)

A small foundation for formal verification in MoonBit, with reusable logical models and lemmas, implementations with contracts, and runtime differential checks.

## QuickStart

To use a published release, add it to your own project:

```sh
moon add mizchi/veri
```

Add the import and proof setting to the consuming package's `moon.pkg`:

```moonbit
import {
  "mizchi/veri/bounds",
}

options("proof-enabled": true)
```

Put this code in `digit.mbt`. Like core `Int::clamp`, `clamp` includes both bounds.
Use `clamp_half_open(value, lower, upper)` for an exclusive upper bound.
Both functions require valid bounds; their proof preconditions are not runtime checks.

```moonbit
pub fn digit(value : Int) -> Int where {
  proof_ensure: result => 0 <= result && result <= 9,
} {
  @bounds.clamp(value, 0, 9)
}

test "clamp includes its upper bound" {
  assert_eq(digit(10), 9)
}
```

```sh
moon test --target js
moon prove
```

This minimal proof uses bundled Why3 and Z3 on PATH. Runtime API use alone does
not require a solver, Node.js, or just. Logical types, `model`, lemmas, and
predicates are proof-only and cannot be called in ordinary runtime code.
For complex BV/real proofs that need additional solver configuration, see the
[verification guide](docs/verification.md).

## Documentation

| Guide | Contents |
| --- | --- |
| [Package index](docs/packages.md) | Available models, APIs, and guarantees |
| [Runtime APIs and graph checking](docs/toolkit.md) | Map / Set, search, checked arithmetic, codecs, Union-Find, parsers, paths, and topology |
| [Collections and arrays](docs/collections.md) | Lists, stacks, queues, priority queues, trees, and FixedArray update contracts |
| [Bitvectors and numeric models](docs/numerics.md) | Fixed-width bits, orders, number theory, reals, and rounding errors |
| [Verification guide](docs/verification.md) | Solver setup, moon prove, QuickCheck, and shrinking |
| [Benchmarks](docs/benchmarks.md) | Core comparisons, measurement conditions, and tuning results |
| [Proof architecture](docs/architecture.md) | Why3 / SMT-LIB bindings, runtime correspondence, and trusted boundaries |
| [IEEE 754](docs/floating-point.md) | Float / Double APIs, reference checks, proof scope, and limitations |
| [Temporal model checking](docs/temporal.md) | moonx, Z3 / Apalache, and TaskGroup / lease-clock examples |

## License

[Apache-2.0](LICENSE).
