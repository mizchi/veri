default:
    @just --list

# Check the installed MoonBit/Why3/Z3 toolchain.
doctor:
    node tools/doctor.mjs

fmt:
    moon fmt
    moon info

check:
    moon fmt --check
    moon check --deny-warn

# Prove both workspace members using the bundled ~/.moon/share/why3 data.
prover-config:
    node tools/configure-why3.mjs

# Bound package concurrency so solver time limits remain useful as packages grow.
prove: prover-config
    moon prove -j 2 --why3-config _build/why3/why3.conf
    moon -C examples prove -j 2 --why3-config ../_build/why3/why3.conf

# The same integer contracts under the bundled machine-integer model.
prove-machine: prover-config
    MOON_PROVE_PRELUDE_OVERRIDE="$HOME/.moon/lib/prelude_proof_machine_int" moon prove bounds --target-dir _build/machine
    MOON_PROVE_PRELUDE_OVERRIDE="$HOME/.moon/lib/prelude_proof_machine_int" moon prove runtime/uint32 --target-dir _build/machine --why3-config _build/why3/why3.conf
    MOON_PROVE_PRELUDE_OVERRIDE="$HOME/.moon/lib/prelude_proof_machine_int" moon prove runtime/uint64 --target-dir _build/machine --why3-config _build/why3/why3.conf
    MOON_PROVE_PRELUDE_OVERRIDE="$HOME/.moon/lib/prelude_proof_machine_int" moon prove runtime/array --target-dir _build/machine
    MOON_PROVE_PRELUDE_OVERRIDE="$HOME/.moon/lib/prelude_proof_machine_int" moon -C examples prove bridges --target-dir _build/machine --why3-config ../_build/why3/why3.conf

# Collection contracts also use mathematical lengths with checked runtime Ints.
prove-collections-machine: prover-config
    for collection_package in runtime/list runtime/stack runtime/queue runtime/pqueue runtime/bintree runtime/bintree/search; do MOON_PROVE_PRELUDE_OVERRIDE="$HOME/.moon/lib/prelude_proof_machine_int" moon prove "$collection_package" --target-dir _build/collections-machine --why3-config _build/why3/why3.conf || exit; done
    MOON_PROVE_PRELUDE_OVERRIDE="$HOME/.moon/lib/prelude_proof_machine_int" moon -C examples prove collections --target-dir _build/collections-machine --why3-config ../_build/why3/why3.conf

test target="js":
    moon test --target {{target}}

# Run only the reproducible QuickCheck properties (also included in normal tests).
quickcheck target="js":
    moon test --target {{target}} --filter 'quickcheck:*'

# Compare collection workloads with core and save unrounded results and ratios.
bench target="native":
    node tools/bench-collections.mjs {{target}}

# Fail unless every comparison is within the limit in both measurement orders.
bench-check target="native" max_ratio="1.0":
    node tools/bench-collections.mjs {{target}} --max-ratio {{max_ratio}}

# Keep targets sequential to avoid competition for CPU during measurement.
bench-backends:
    just bench native
    just bench js
    just bench wasm
    just bench wasm-gc

test-backends:
    moon test --target js
    moon test --target wasm
    moon test --target wasm-gc
    moon test --target native

test-release:
    moon test --release --target js
    moon test --release --target wasm
    moon test --release --target wasm-gc
    moon test --release --target native

test-tools:
    node --test tools/*.test.mjs

# Report compiler support separately from IEEE correctness.
fp-capabilities:
    node tools/check-fp-capabilities.mjs

# Check whether contracts can directly call the installed core collections.
core-capabilities:
    node tools/check-core-capabilities.mjs

# Fail unless deliberately false statements in each model remain unproved.
negative:
    node tools/check-negative.mjs

# UNSAT proofs and concrete SAT witnesses for FP, bitvectors, arrays, and strings.
smt:
    node tools/check-smt.mjs

vectors:
    node tools/generate-floats.mjs
    node tools/generate-runtime.mjs

vectors-check:
    node tools/generate-floats.mjs --check
    node tools/generate-runtime.mjs --check

verify: doctor check test-tools fp-capabilities core-capabilities prove prove-machine prove-collections-machine negative smt vectors-check test-backends test-release
