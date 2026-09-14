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

prove: prover-config
    moon prove --why3-config _build/why3/why3.conf
    moon -C examples prove --why3-config ../_build/why3/why3.conf

# The same integer contracts under the bundled machine-integer model.
prove-machine: prover-config
    MOON_PROVE_PRELUDE_OVERRIDE="$HOME/.moon/lib/prelude_proof_machine_int" moon prove bounds --target-dir _build/machine
    MOON_PROVE_PRELUDE_OVERRIDE="$HOME/.moon/lib/prelude_proof_machine_int" moon prove runtime/uint32 --target-dir _build/machine --why3-config _build/why3/why3.conf
    MOON_PROVE_PRELUDE_OVERRIDE="$HOME/.moon/lib/prelude_proof_machine_int" moon prove runtime/uint64 --target-dir _build/machine --why3-config _build/why3/why3.conf
    MOON_PROVE_PRELUDE_OVERRIDE="$HOME/.moon/lib/prelude_proof_machine_int" moon prove runtime/array --target-dir _build/machine
    MOON_PROVE_PRELUDE_OVERRIDE="$HOME/.moon/lib/prelude_proof_machine_int" moon -C examples prove bridges --target-dir _build/machine --why3-config ../_build/why3/why3.conf

test target="js":
    moon test --target {{target}}

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

# Fail unless deliberately false statements in each model remain unproved.
negative:
    node tools/check-negative.mjs

# UNSAT proofs and concrete SAT witnesses for FP, bitvectors, arrays, and strings.
smt:
    node tools/check-smt.mjs

vectors:
    node tools/generate-float64.mjs
    node tools/generate-runtime.mjs

vectors-check:
    node tools/generate-float64.mjs --check
    node tools/generate-runtime.mjs --check

verify: doctor check test-tools prove prove-machine negative smt vectors-check test-backends test-release
