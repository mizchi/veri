# Shared model client and driver

[日本語](README.ja.md)

Job, TaskGroup, and lease-clock share model export and certificate replay.
A new model supplies executable states, events, transitions, and predicates through
`Client`; a small driver decodes its configuration. The shared library lives at
`mizchi/veri/model_check`, and the CLI at `mizchi/veri/cmd/model-check`.
Only model-specific code stays in `examples`. These additions have not been published yet.

## Check with moonx

Run from this checkout's root. The CLI requires MoonBit and Z3; it does not run Node.js.

```sh
# Find two writers and automatically replay the witness through MoonBit step
moonx veri.mbtx check lease_clock/driver --module examples \
  --config '{"variant":0,"bound":8}' --safety single_writer --bound 8

# Check response with weak fairness for completion
moonx veri.mbtx check temporal/driver --module examples \
  --config '{"allow_drop":false}' --response pending done --fair --bound 8

moonx veri.mbtx --help
```

`veri.mbtx` only launches the checkout's `cmd/model-check` on Wasm.
Model execution, SMT generation, Z3 communication, result decoding, and certificate
replay are implemented in MoonBit. Process execution uses `moonbitlang/async/shell`
with an argument array, not shell command concatenation.
You can also use `moon run cmd/model-check --target wasm -- ...` or `just model-check ...`.

After publishing a version containing these additions, the registry entry point
will work without this checkout. Point `--module` at the project containing your model:

```sh
moonx mizchi/veri/cmd/model-check check my_model/driver \
  --module ./my_project --config '{}' --safety safe --bound 8
```

`export` prints the model graph as JSON. `replay --witnesses FILE` reads a JSON array
of `{states, actions, loop_start?}` and returns acceptance booleans.
Use `--config-file FILE` for configuration files. Select exactly one property:
`--safety P`, `--reachable P`, or `--response P Q`. `--fair` uses the model's suggested
justice actions; `--justice '[1,2]'` selects them explicitly.
The model's exploration depth in `--config` is separate from the CLI's SMT `--bound`.

Results are JSON on stdout. Finding a counterexample is a successful query and exits
with status 0. Invalid input, Z3 `unknown`, timeouts, process failures, and rejected
automatic replay exit unsuccessfully. The generic CLI reports bounded results,
not unbounded proofs.

The [runner](runner/runner.mbt) also exposes a MoonBit API:

```moonbit
let driver : @runner.Driver = {
  driver_pkg: "lease_clock/driver", module_dir: "examples", target: "wasm",
}
let result = driver.check(
  { "variant": 0, "bound": 8 }, @model_check.Safety("single_writer"), bound=8,
)
```

Use this inside an `async fn`. `Driver::load` and `Driver::replay` are also available.
The process runner and CLI support Wasm/native; the pure model API, driver, and
SMT generator support js/wasm/wasm-gc/native.

## Use existing JavaScript tools

Run this as a Node.js ES module at the repository root:

```js
import {createModelClient} from "./tools/model-client.mjs";

const client = createModelClient({
  driver: "lease_clock/driver",
  defaults: {variant: 0, bound: 8},
});
const property = {kind: "safety", predicate: "single_writer"};
const model = client.load();
const result = client.check(property, {bound: 8});
console.log(result.result); // counterexample
console.log(result.witness.actions.map(a => model.actions[a]));
console.log(client.replay([result.witness], {property})); // [true]
```

`check` searches with Z3 and replays any witness through the actual MoonBit `step`.
It throws if replay rejects that witness. `replay` also checks external certificates.
For Apalache, pass the same exported model to `finiteTla`, decode its trace with
`decodeFiniteTrace`, and call the same `replay`. The existing `just apalache` and
`just apalache-lease-clock` commands demonstrate this path.

| Method | Behavior |
| --- | --- |
| `load(config = {})` | Build the configured model and validate its exported graph |
| `check(property, {config, bound, justice, onQuery})` | Bounded Z3 search followed by MoonBit replay |
| `replay(witnesses, {config, property, justice})` | Return one acceptance boolean per certificate |

`config` shallowly overrides `defaults`. You can also configure `cwd`, `moduleDir`,
and `target`, which default to this repository, `examples`, and `js`.
Replay must use the same model configuration that produced the certificate.

| Property | JavaScript value | Certificate acceptance |
| --- | --- | --- |
| Safety | `{kind: "safety", predicate: "safe"}` | The predicate becomes false along the trace |
| Reachability | `{kind: "reachability", predicate: "done"}` | The predicate holds in the final state |
| Response | `{kind: "response", trigger: "pending", goal: "done"}` | An infinite lasso violates `G(trigger => F goal)` |

`justice` lists action IDs subject to weak fairness. It defaults to `[]`;
the suggested `model.justice` is never applied automatically. Pass fairness
explicitly to both checking and replay. An action that leaves the state unchanged
does not count as enabled progress for fairness.

## Connect a MoonBit model

[types.mbt](types.mbt) defines `Client[State, Event, Snapshot]`.
`State` needs `Eq`; the driver needs `Snapshot: ToJson`.
Treat states as immutable and compare the entire modeled state with `Eq`.

| Field | Adapter responsibility |
| --- | --- |
| `initial` / `states` | Actual initial state and executable states in ID order |
| `events` | Events in ID order; enumerate argument choices explicitly |
| `step` | Deterministic `(State, Event) -> State?`; disabled actions return `None` |
| `holds` | `(State, String) -> Bool?`; unknown predicate names return `None` |
| `model` | A matching `Model[Snapshot]` for JSON export |

`model` contains `initial`, `actions`, `states`, `transitions`, `predicates`,
`justice`, and `exploration`. A disabled transition is `-1`.
Replay evaluates actual states, `step`, and `holds`; it does not use exported
edges or predicate values as evidence. No snapshot-to-state decoder is needed.

The [Job adapter](../examples/temporal/explorer/explorer.mbt) enumerates an entire finite
type domain; the [lease-clock adapter](../examples/lease_clock/explorer/explorer.mbt) uses
bounded BFS through `explore`; the [TaskGroup adapter](../examples/task_group/explorer/explorer.mbt)
enumerates the reachable closure. The adapters capture model configuration in the executable callbacks.

A driver only needs its configuration type and a call to `serve`.
The [Job driver](../examples/temporal/driver/main.mbt) is:

```moonbit
struct Config {
  allow_drop : Bool
} derive(@json.FromJson)

fn main {
  @model_driver.serve((config : Config) => @explorer.client(config.allow_drop))
}
```

Its `moon.pkg` imports the model explorer,
`"mizchi/veri/model_check/driver" @model_driver`, and `"moonbitlang/core/json"`.
`serve` accepts pure builders and builders that raise exploration errors.
Use `Client::accepts(Property, Witness, justice=...)` without I/O, or
`dispatch(argument, make_client)` to test the JSON boundary alone.

## Protocol and scope

The driver reads one JSON argument and returns `{version: 1, result: ...}`.
A replay request looks like this:

```json
{
  "version": 1,
  "mode": "replay",
  "config": {"allow_drop": false},
  "property": {"kind": "response", "trigger": "pending", "goal": "done"},
  "justice": [],
  "witnesses": [{"states": [0, 1, 1], "actions": [0, 2], "loop_start": 1}]
}
```

For `export`, omit `property` and send empty `justice` and `witnesses` arrays.
JavaScript certificates use `{states, actions, loop}`. The client converts
`loop: null` into an absent `loop_start` key for MoonBit's optional-field decoder.
A lasso must end at `states[loop]`. Unsupported versions, malformed configuration,
and exhausted exploration resources exit unsuccessfully instead of passing a check.

An incomplete `exploration: Some(scope)` forbids response checking and replay
beyond its explored depth. `None` declares a complete state domain or reachable
closure; never use it to hide a cutoff. Exceeding `explore`'s state limit raises.

These are executable checks, not generic inductive proofs. The `moon prove`
contracts in `temporal/client` and `task_group/client` remain model-specific.
Their proof coverage does not extend to JSON transport or this shared evaluator.

```sh
just test-model-check   # Shared evaluator/protocol, four backends, debug/release
just verify-model-check # Also check all three models with Z3 and replay witnesses
```
