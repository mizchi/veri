# Practical model checking workflows

[日本語](model-workflows.ja.md) | [README](../README.md)

## CI suites

From the checkout root run `just model-suite`, or supply your own suite:

```sh
moonx veri.mbtx test checks/model_check/suite.json
```

A suite is `{ "version": 1, "cases": [...] }`. Each case requires `name`, `driver`,
`property`, and `expect`. `module_dir` is relative to the suite file, defaulting to its
parent directory. Defaults are `{}` for `config`, `wasm` for `target`, and 8 for
`bound`. Choose `fair: true` or explicit `justice: [1]`; supplying both is rejected.

For bounded checks, `expect` is one of `counterexample`, `witness`, `no-counterexample-up-to-bound`,
or `unreachable-up-to-bound`; complete results are described below. Duplicate names and expectations incompatible with
the property are rejected. Expected counterexamples let deliberately broken
models serve as regression controls. All case results are returned as JSON; the
exit status is zero only if every expectation matches. Unknown, timeout, rejected
replay, and process failures are errors and cannot be expected successes. Failed
cases do not stop the remaining cases. An invalid suite fails before any checks.

The existing `check` command remains a query: finding a counterexample exits zero.
A successful bounded check is not an unbounded proof.

## Save and explain counterexamples

```sh
moonx veri.mbtx check lease_clock/driver --module examples \
  --config '{"variant":0,"bound":4}' --safety single_writer --bound 4 --save trace.json
moonx veri.mbtx explain trace.json
moonx veri.mbtx replay-file trace.json
```

`--save` records configuration, property, fairness, the entire finite model, and
the result in a version 1 bundle. `explain` reports named events and before/after
values by JSON pointer, the safety violation index, and a response lasso's loop
start. It first validates the certificate against the saved graph. `replay-file`
requires an identical current model and replays the real `step` / `holds` functions.
Use `--module DIR` to relocate a checkout. This checks model identity and replay,
not executable identity. Only execute bundles you trust. Results without witnesses
can be saved but cannot be explained or replayed as certificates.
`--complete --save FILE` records `complete: true` in the bundle. Existing version 1
bundles without this field still replay as bounded checks. Complete checks do not use solver `limits`.

`model_check.minimize` shrinks arbitrary inputs or configurations using supplied
candidates, a nonnegative cost, and a failure-reproduction predicate. It accepts
only a strictly smaller failing candidate and stops at the attempt budget. It can
use core `Shrink::shrink`. Replay with fresh state on every attempt. Shrinking is
greedy and does not claim global minimality.

## Named model definitions

Provide `initial`, named `actions`, `step`, named `predicates`, `snapshot`, and
fairness action names in `model_check.Spec[State, Event, Snapshot]`.
`build_client(spec, max_depth=..., max_states=...)` derives exploration, transition
and predicate tables, and executable replay from those same definitions. Duplicate
names and unknown fairness actions are rejected. States must be immutable, Eq must
compare the full state, and callbacks must be deterministic. Snapshots are only
for presentation, never state identity.

Use `client_from_states(spec, states)` when identifiers must match existing proofs.
The explicit domain must be duplicate-free and closed under every event. Bounded
`build_client` exploration records omitted successors in `exploration`, preserving
the distinction from complete exploration. The three existing model explorers show
both construction styles.

## Deadlocks and response preconditions

`check ... --deadlock terminal` finds a reachable state where `terminal` is false
and no event is enabled. Normal termination is excluded; enabled self loops count
as transitions. Use response/fairness checks to detect lack of progress with self
loops. Truncated frontier rows are never mistaken for deadlocks, and certificates
are replayed against every actual event. The suite property is
`{ "kind": "deadlock", "terminal": "terminal" }`.

`--response pending done --require-trigger` additionally requires a reachable
`pending` state within the same bound. Otherwise it raises `TriggerUnreachable`.
Suites use `require_trigger: true`. This checks bounded trigger reachability,
not that a request occurs on every execution.
With `--complete`, it checks reachability throughout the finite model and raises
`TriggerUnreachableInCompleteModel` when no trigger is reachable.

## Exploration and resource budgets

Pass `state_hash=state => state.hash()` to `explore` / `build_client` to index
states by hash, resolving collisions with Eq. Equal states must hash equally.
Without it, lookup uses linear Eq comparisons. `max_states` defaults to 4,096;
`max_transitions` limits table cells, including disabled entries, to 4,000,000 by
default. Exceeding either raises an error. Exploration and SMT depths support up
to 1,000,000; feasible depths depend on the model and budgets.

The CLI keeps one Z3 process per property, extending prefixes and checking
properties with push/pop. `--timeout-ms` bounds the entire solver session (default
60,000); `--memory-mb` sets Z3's memory limit (512). `--max-query-bytes` and
`--max-output-bytes` bound total session traffic (16 MiB each). Suites accept a
`limits` object with `timeout_ms`, `memory_mb`, `max_query_bytes`, and
`max_output_bytes`. Trigger reachability uses a separate session. Driver processes
have separate 60-second/16-MiB limits. The memory setting covers Z3, not total
MoonBit process RSS.

```sh
moonx veri.mbtx check temporal/driver --module examples \
  --config '{"allow_drop":false}' --safety safe --bound 32 --timeout-ms 60000
moonx veri.mbtx check temporal/driver --module examples \
  --config '{"allow_drop":false}' --safety safe --complete
```

`--complete` checks a declared-complete finite model without Z3. Safety,
reachability, and deadlocks use BFS; response uses strongly connected components.
Partial exploration is rejected. Complete response checks accept fairness.
Results without witnesses are
`safe-for-complete-model` or `unreachable-in-complete-model`. The `bound` field is
the certificate's transition count when present, otherwise the maximum shortest
depth of checked states. Suites use `complete: true` and
these result names, omitting `bound` and solver `limits`. This is exhaustive
checking of the supplied finite model, not an infinite-state implementation
theorem or a `moon prove` proof. The JavaScript compatibility checker retains its
existing small-model resource limits.

```sh
moonx veri.mbtx check temporal/driver --module examples \
  --config '{"allow_drop":false}' --response pending done --complete --fair --require-trigger
moonx veri.mbtx check temporal/driver --module examples \
  --config '{"allow_drop":true}' --response pending done --complete --fair --save dropped.json
moonx veri.mbtx explain dropped.json
```

A violation of `G(pending => F done)` exists when a reachable request can avoid
`done` forever along a fair closed walk. Walks combining several simple cycles
are supported. Weak fairness follows the existing replay evaluator: each justice
action must be disabled or leave the state unchanged somewhere on the cycle, or
the cycle must take a state-changing edge with that action. Response concerns
infinite executions; no implicit self-loop is added to dead ends. Use deadlock
checking for those states. Generated lassos replay against both the table and the
actual driver. They need not be shortest; construction exceeding one million
transitions raises an error.

## Compare operation traces with implementations

`testing/state_machine` separates two definitions:

- `Model[M, Command, Output, View]`: independent reference `initial`, `step`, `observe`.
- `System[S, Command, Output, View]`: concrete `create`, `step`, `observe`, `close`.

A step returns the next state and command output. The model may return None when
a command violates its precondition. `replay(model, system, commands)` compares
initial observations and every subsequent output/state, returning `Matched`,
`Mismatch`, or `InvalidCommand` and the first mismatch index. `check` uses core
QuickCheck generation, reproducible seeds, and standard command/array shrinking.
Invalid traces are filtered both during generation and shrinking. Each replay
creates and closes fresh concrete state. Represent expected failures in Output,
for example with Result; unexpected exceptions fail the check. Observations must
be immutable snapshots, unaffected by later updates.

`testing/state_machine/async` accepts async create/step/observe/close callbacks.
It provides `replay`, `find_failure`, and `shrink_failure` with core generators and
shrinkers, per-replay timeouts, and cleanup. Commands are awaited sequentially;
adapters and events must explicitly implement any scheduler control. This is
not a formal correspondence proof for arbitrary async code. The synchronous API
supports all four backends; the async API supports Wasm/native.

See [Queue comparison and shrinking](../testing/state_machine/replay_test.mbt) and
[async replay and shrinking](../testing/state_machine/async/replay_test.mbt).
`just test-model-check` includes these checks.
