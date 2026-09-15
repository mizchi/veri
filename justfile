default:
    @just --list

# Check the installed MoonBit/Why3/Z3/CVC5 toolchain.
doctor:
    node tools/doctor.mjs

# Fetch pinned CVC5 into _build/solvers, checking the official SHA-256 digest.
setup-solvers:
    node tools/setup-solvers.mjs

fmt:
    moon fmt
    moon info

check:
    moon fmt --check
    moon check --deny-warn

# Prove both workspace members using the bundled ~/.moon/share/why3 data.
prover-config: setup-solvers
    node tools/configure-why3.mjs

# Bound package concurrency so solver time limits remain useful as packages grow.
prove: prover-config
    moon prove -j 2 --why3-config _build/why3/why3.conf
    moon -C examples prove -j 2 --why3-config ../_build/why3/why3.conf

# The same integer contracts under the bundled machine-integer model.
prove-machine: prover-config
    for bitvector_package in bitvector/laws bitvector/laws/integers; do MOON_PROVE_PRELUDE_OVERRIDE="$HOME/.moon/lib/prelude_proof_machine_int" moon prove "$bitvector_package" --target-dir _build/machine --why3-config _build/why3/why3.conf || exit; done
    MOON_PROVE_PRELUDE_OVERRIDE="$HOME/.moon/lib/prelude_proof_machine_int" moon prove strings --target-dir _build/machine --why3-config _build/why3/why3.conf
    MOON_PROVE_PRELUDE_OVERRIDE="$HOME/.moon/lib/prelude_proof_machine_int" moon prove bounds --target-dir _build/machine
    MOON_PROVE_PRELUDE_OVERRIDE="$HOME/.moon/lib/prelude_proof_machine_int" moon prove runtime/uint32 --target-dir _build/machine --why3-config _build/why3/why3.conf
    MOON_PROVE_PRELUDE_OVERRIDE="$HOME/.moon/lib/prelude_proof_machine_int" moon prove runtime/uint64 --target-dir _build/machine --why3-config _build/why3/why3.conf
    MOON_PROVE_PRELUDE_OVERRIDE="$HOME/.moon/lib/prelude_proof_machine_int" moon prove arrays/range --target-dir _build/machine --why3-config _build/why3/why3.conf
    MOON_PROVE_PRELUDE_OVERRIDE="$HOME/.moon/lib/prelude_proof_machine_int" moon prove runtime/array --target-dir _build/machine --why3-config _build/why3/why3.conf
    MOON_PROVE_PRELUDE_OVERRIDE="$HOME/.moon/lib/prelude_proof_machine_int" moon -C examples prove bridges --target-dir _build/machine --why3-config ../_build/why3/why3.conf
    MOON_PROVE_PRELUDE_OVERRIDE="$HOME/.moon/lib/prelude_proof_machine_int" moon -C examples prove bitvector --target-dir _build/machine --why3-config ../_build/why3/why3.conf

# Collection contracts also use mathematical lengths with checked runtime Ints.
prove-collections-machine: prover-config
    for collection_package in runtime/list runtime/stack runtime/queue runtime/pqueue runtime/bintree runtime/bintree/search; do MOON_PROVE_PRELUDE_OVERRIDE="$HOME/.moon/lib/prelude_proof_machine_int" moon prove "$collection_package" --target-dir _build/collections-machine --why3-config _build/why3/why3.conf || exit; done
    MOON_PROVE_PRELUDE_OVERRIDE="$HOME/.moon/lib/prelude_proof_machine_int" moon -C examples prove collections --target-dir _build/collections-machine --why3-config ../_build/why3/why3.conf

# Order, arithmetic and real/IEEE error models under checked machine integers.
prove-foundations-machine: prover-config
    for foundation_package in relations seq/order integer/laws integer/aggregate/laws number/laws number/parity real/laws ieee754/error ieee754/error/operations runtime/number runtime/int32 runtime/int64 runtime/conversion runtime/bytes algebra encoding encoding/bitvector graph fset fmap runtime/search union_find runtime/graph/checker runtime/graph/topology runtime/graph; do MOON_PROVE_PRELUDE_OVERRIDE="$HOME/.moon/lib/prelude_proof_machine_int" moon prove "$foundation_package" --target-dir _build/foundations-machine --why3-config _build/why3/why3.conf || exit; done
    MOON_PROVE_PRELUDE_OVERRIDE="$HOME/.moon/lib/prelude_proof_machine_int" moon -C examples prove foundations --target-dir _build/foundations-machine --why3-config ../_build/why3/why3.conf
    MOON_PROVE_PRELUDE_OVERRIDE="$HOME/.moon/lib/prelude_proof_machine_int" moon -C examples prove toolkit --target-dir _build/foundations-machine --why3-config ../_build/why3/why3.conf

test target="js":
    moon test --target {{target}}

# Run only the reproducible QuickCheck properties (also included in normal tests).
quickcheck target="js":
    moon test --target {{target}} --filter 'quickcheck:*'

# Graph properties include shrinking, an Int64 oracle and corrupted certificates.
quickcheck-graph target="js":
    moon test runtime/graph --target {{target}} --filter 'quickcheck:*' --deny-warn

# Complete shortest-path/topology checkers, graph laws and clients under both integer models.
prove-graph: prover-config
    moon prove runtime/graph/checker --why3-config _build/why3/why3.conf
    moon prove runtime/graph/topology --why3-config _build/why3/why3.conf
    moon prove runtime/graph --why3-config _build/why3/why3.conf
    moon prove graph --why3-config _build/why3/why3.conf
    moon -C examples prove toolkit --why3-config ../_build/why3/why3.conf
    MOON_PROVE_PRELUDE_OVERRIDE="$HOME/.moon/lib/prelude_proof_machine_int" moon prove runtime/graph/checker --target-dir _build/graph-machine --why3-config _build/why3/why3.conf
    MOON_PROVE_PRELUDE_OVERRIDE="$HOME/.moon/lib/prelude_proof_machine_int" moon prove runtime/graph/topology --target-dir _build/graph-machine --why3-config _build/why3/why3.conf
    MOON_PROVE_PRELUDE_OVERRIDE="$HOME/.moon/lib/prelude_proof_machine_int" moon prove runtime/graph --target-dir _build/graph-machine --why3-config _build/why3/why3.conf
    MOON_PROVE_PRELUDE_OVERRIDE="$HOME/.moon/lib/prelude_proof_machine_int" moon prove graph --target-dir _build/graph-machine --why3-config _build/why3/why3.conf
    MOON_PROVE_PRELUDE_OVERRIDE="$HOME/.moon/lib/prelude_proof_machine_int" moon -C examples prove toolkit --target-dir _build/graph-machine --why3-config ../_build/why3/why3.conf

# Includes all graph QuickCheck and regression tests in debug and release.
verify-graph: check prove-graph
    just negative graph runtime/graph/checker runtime/graph runtime/graph/topology
    for graph_target in js wasm wasm-gc native; do moon test runtime/graph runtime/graph/checker runtime/graph/topology --target "$graph_target" --deny-warn || exit; moon test runtime/graph runtime/graph/checker runtime/graph/topology --release --target "$graph_target" --deny-warn || exit; done

# New core bridges, search contracts, topology, partitions and cursor composition.
prove-extensions: prover-config
    for extension_package in fset fmap runtime/search union_find encoding graph runtime/graph/checker runtime/graph/topology runtime/graph; do moon prove "$extension_package" --why3-config _build/why3/why3.conf || exit; MOON_PROVE_PRELUDE_OVERRIDE="$HOME/.moon/lib/prelude_proof_machine_int" moon prove "$extension_package" --target-dir _build/extensions-machine --why3-config _build/why3/why3.conf || exit; done
    moon -C examples prove toolkit --why3-config ../_build/why3/why3.conf
    MOON_PROVE_PRELUDE_OVERRIDE="$HOME/.moon/lib/prelude_proof_machine_int" moon -C examples prove toolkit --target-dir _build/extensions-machine --why3-config ../_build/why3/why3.conf

# Consume all public graph soundness contracts and probe ArrayView adapter lowering.
graph-capabilities:
    node tools/check-graph-capabilities.mjs

# Shrinking properties, regressions, proof laws and false controls.
verify-extensions: check core-capabilities graph-capabilities prove-extensions
    just negative fset fmap runtime/search union_find graph runtime/graph/checker runtime/graph runtime/graph/topology
    for extension_target in js wasm wasm-gc native; do moon test runtime/map runtime/set runtime/search runtime/union_find runtime/bytes/cursor runtime/graph runtime/graph/checker runtime/graph/topology --target "$extension_target" --deny-warn || exit; moon test runtime/map runtime/set runtime/search runtime/union_find runtime/bytes/cursor runtime/graph runtime/graph/checker runtime/graph/topology --release --target "$extension_target" --deny-warn || exit; done

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

# Build an archive and execute/prove the bilingual quickstart as its consumer.
package-check:
    node tools/check-package.mjs

# Report compiler support separately from IEEE correctness.
fp-capabilities:
    node tools/check-fp-capabilities.mjs

# Report native casts and narrow integer frontend support separately from value laws.
conversion-capabilities:
    node tools/check-conversion-capabilities.mjs

# Check whether contracts can directly call the installed core collections.
core-capabilities:
    node tools/check-core-capabilities.mjs

# Report old-state/snapshot support and require rejection of mutable aliases.
array-capabilities: setup-solvers
    node tools/check-array-capabilities.mjs

# Fail unless deliberately false statements remain unproved; optionally select packages.
[positional-arguments]
negative *packages: setup-solvers
    node tools/check-negative.mjs "$@"

# UNSAT proofs and concrete SAT witnesses for FP, bitvectors, arrays, and strings.
smt:
    node tools/check-smt.mjs

# Fixed job model: inductive safety and bounded liveness/fairness experiments.
temporal:
    node tools/check-temporal.mjs

# Export the actual MoonBit transition table, search it, and replay certificates.
temporal-bridge:
    node tools/check-temporal-bridge.mjs

# Install pinned Apalache and Java through Nix, local to _build.
setup-apalache:
    mkdir -p _build
    nix build . --out-link _build/apalache-bin

# Cross-check Job and TaskGroup with Apalache/Z3 and replay all witnesses in MoonBit.
apalache: setup-apalache
    node --test tools/apalache.test.mjs
    node tools/check-apalache.mjs

prove-temporal: prover-config
    moon -C examples prove temporal --why3-config ../_build/why3/why3.conf
    moon -C examples prove temporal/client --why3-config ../_build/why3/why3.conf
    just prove-temporal-machine

prove-temporal-machine: prover-config
    MOON_PROVE_PRELUDE_OVERRIDE="$HOME/.moon/lib/prelude_proof_machine_int" moon -C examples prove temporal --target-dir _build/temporal-machine --why3-config ../_build/why3/why3.conf
    MOON_PROVE_PRELUDE_OVERRIDE="$HOME/.moon/lib/prelude_proof_machine_int" moon -C examples prove temporal/client --target-dir _build/temporal-machine --why3-config ../_build/why3/why3.conf

verify-temporal: check prove-temporal temporal temporal-bridge
    just negative examples/temporal
    for temporal_target in js wasm wasm-gc native; do moon -C examples test temporal --target "$temporal_target" --deny-warn || exit; moon -C examples test temporal --target "$temporal_target" --release --deny-warn || exit; done

# Bounded TaskGroup interleavings, fairness, injected bugs and MoonBit replay.
task-group:
    node tools/check-task-group.mjs

prove-task-group: prover-config
    moon -C examples prove task_group --why3-config ../_build/why3/why3.conf
    moon -C examples prove task_group/client --why3-config ../_build/why3/why3.conf
    just prove-task-group-machine

prove-task-group-machine: prover-config
    MOON_PROVE_PRELUDE_OVERRIDE="$HOME/.moon/lib/prelude_proof_machine_int" moon -C examples prove task_group --target-dir _build/task-group-machine --why3-config ../_build/why3/why3.conf
    MOON_PROVE_PRELUDE_OVERRIDE="$HOME/.moon/lib/prelude_proof_machine_int" moon -C examples prove task_group/client --target-dir _build/task-group-machine --why3-config ../_build/why3/why3.conf

test-task-group:
    node --test tools/finite-temporal.test.mjs tools/task-group.test.mjs
    for task_group_target in js wasm wasm-gc native; do moon -C examples test task_group --target "$task_group_target" --deny-warn || exit; moon -C examples test task_group --target "$task_group_target" --release --deny-warn || exit; done
    for task_group_target in js wasm native; do moon -C examples test task_group/runtime --target "$task_group_target" --deny-warn || exit; moon -C examples test task_group/runtime --target "$task_group_target" --release --deny-warn || exit; done

verify-task-group: check prove-task-group task-group test-task-group
    just negative examples/task_group

# Quint lease/clock examples: bounded bug search and exhaustive repaired model.
lease-clock:
    node tools/check-lease-clock.mjs

test-lease-clock:
    node --test tools/lease-clock.test.mjs tools/model-scope.test.mjs
    for lease_target in js wasm wasm-gc native; do moon -C examples test lease_clock --target "$lease_target" --deny-warn || exit; moon -C examples test lease_clock --target "$lease_target" --release --deny-warn || exit; done

verify-lease-clock: check lease-clock test-lease-clock

# Shared model protocol, executable certificate evaluator and all three adapters.
test-model-check:
    node --test tools/model-client.test.mjs tools/model-scope.test.mjs tools/finite-temporal.test.mjs
    for model_target in js wasm wasm-gc native; do moon test model_check model_check/driver model_check/smt model_check/suite testing/state_machine --target "$model_target" --deny-warn || exit; moon test model_check model_check/driver model_check/smt model_check/suite testing/state_machine --target "$model_target" --release --deny-warn || exit; done
    for workflow_target in wasm native; do moon test testing/state_machine/async --target "$workflow_target" --deny-warn || exit; moon test testing/state_machine/async --target "$workflow_target" --release --deny-warn || exit; done
    node --test tools/moon-model-cli.test.mjs tools/model-suite.test.mjs tools/complete-response.test.mjs

# MoonBit CLI, executed by moonx on Wasm. No Node.js is used by this command.
[positional-arguments]
model-check *args:
    moonx veri.mbtx "$@"

verify-model-check: check temporal-bridge task-group lease-clock test-model-check

# Optional second backend. Checks the same finite prefixes and replays ITF traces.
apalache-lease-clock: setup-apalache
    node tools/check-lease-clock.mjs --apalache

vectors:
    node tools/generate-floats.mjs
    node tools/generate-runtime.mjs

vectors-check:
    node tools/generate-floats.mjs --check
    node tools/generate-runtime.mjs --check

verify: setup-solvers doctor check test-tools fp-capabilities conversion-capabilities core-capabilities array-capabilities graph-capabilities prove prove-machine prove-collections-machine prove-foundations-machine prove-temporal-machine prove-task-group-machine negative smt temporal temporal-bridge task-group test-task-group test-model-check vectors-check test-backends test-release package-check

# Expected outcomes for CI, including deliberately failing models.
model-suite:
    moonx veri.mbtx test checks/model_check/suite.json
