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

# moon prove automatically uses ~/.moon/share/why3 in this toolchain.
prove:
    moon prove

# The same integer contracts under the bundled machine-integer model.
prove-machine:
    MOON_PROVE_PRELUDE_OVERRIDE="$HOME/.moon/lib/prelude_proof_machine_int" moon prove libs/bounds --target-dir _build/machine

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
    node --test tools/solver.test.mjs

# Fail unless a deliberately false IEEE statement is rejected by moon prove.
negative:
    node tools/check-negative.mjs

# UNSAT proofs and a concrete SAT counterexample in the IEEE FP model.
smt:
    node tools/check-fp.mjs

vectors:
    node tools/generate-float64.mjs

vectors-check:
    node tools/generate-float64.mjs --check

verify: doctor check test-tools prove prove-machine negative smt vectors-check test-backends test-release
