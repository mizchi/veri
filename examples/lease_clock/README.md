# Lease clocks and a single writer

[日本語](README.ja.md)

A MoonBit port of the two Quint models from
[the application-modeling article](https://zenn.dev/mizchi/articles/quint-application-modeling).
The source of truth is [`lease_clock.qnt` at Gist revision
3798163](https://gist.github.com/mizchi/58550e8d335a532f15d8e0cd84f57231/3798163170230238b8242043898802e54e4a31c1#file-lease_clock-qnt):
`vulnerable_lease_clock` and `bounded_skew_candidate`.
This example models their semantics; it does not call celld or reproduce a bug
against the Rust implementation.

## Run

From the repository root, with MoonBit, Node.js 24+, Z3 and just:

```sh
just lease-clock          # Z3, exhaustive finite-state check, MoonBit replay
just test-lease-clock     # independent oracle, shrinking, four backends
just verify-lease-clock   # also checks formatting and compilation
just apalache-lease-clock # optional: Nix supplies Apalache 0.62.2 and Java 21
```

Results are saved in `_build/lease-clock/report.json` and, for the optional
second backend, `apalache-report.json`. Each report links its fresh run directory
with JSON graphs, TLA+ sources, SMT queries and any Apalache ITF traces.

## State and actions

The constants match the Quint source: two nodes A/B, one cell, TTL 3 ticks,
wall-clock offsets A=0 and B=1, and maximum global time 6.
Each node records its published lease expiry, monotonic elapsed time since
renewal, whether it still holds its lease, and its locally resident epoch.
The shared owner and its epoch are separate from these local resident epochs.
An owner change is one atomic action, corresponding to the model's CAS assumption.

`State`, `Node`, `Variant` and `Event` are defined in [types.mbt](types.mbt).
[model.mbt](model.mbt) implements immutable updates. `step` returns `None` when
an action's guard is false; `replay` rejects a schedule containing such an action.
The intended inputs are states derived from `initial()` and these transitions.

| Rule | `Vulnerable` | `BoundedSkew` |
| --- | --- | --- |
| May write | Held lease and a resident epoch | Also checks elapsed time `< TTL` |
| Renew | Held lease | Also requires elapsed time `< TTL` |
| Fence | Elapsed time `> TTL` | Elapsed time `>= TTL` |
| Take over | Taker's wall clock sees the owner's expiry | Waits one additional skew tick; taker must be locally live |
| Publish owner | Held lease, new resident epoch | Also requires local liveness |

The events are `AdvanceTime`, `RenewNodeLease(node)`, `FenceExpiredNode(node)`,
`TakeOver(node)` and `PublishCurrentOwner`. The explorer considers both nodes
where applicable, producing eight choices. There is no synthetic wait event.

## The two deterministic examples

The example package can be imported as `"mizchi/veri-examples/lease_clock"`.
The tests use it as `@lease_clock`:

```moonbit
let state = @lease_clock.replay(Vulnerable, @lease_clock.initial(), [
  AdvanceTime, AdvanceTime, TakeOver(B), PublishCurrentOwner,
]).unwrap()
assert_false(@lease_clock.single_writer(Vulnerable, state))
```

At time 2, B's wall clock reads 3, so B may take over A's published expiry of 3.
A still holds its lease and resident epoch 1; publishing B's epoch 2 makes both
nodes writable. The corrected model rejects that early takeover.

```moonbit
let state = @lease_clock.replay(BoundedSkew, @lease_clock.initial(), [
  AdvanceTime, RenewNodeLease(B), AdvanceTime, AdvanceTime,
  TakeOver(B), PublishCurrentOwner,
]).unwrap()
assert_true(@lease_clock.single_writer(BoundedSkew, state))
assert_true(@lease_clock.may_write(BoundedSkew, state, B))
```

At time 3, B can take over, while A's per-write monotonic check already rejects
authorization. A may retain its old resident epoch without being writable.
The repaired model also rejects a renewal that would resurrect A's expired authority.

## Checks and their scope

| Check | Result |
| --- | --- |
| Vulnerable model, depth 3 | No counterexample in that prefix |
| Vulnerable model, depth 8 | A shortest safety counterexample has 4 actions |
| Repaired model, depth 8 | No counterexample; Z3 and Apalache agree |
| Repaired B authorization | Reachable after 6 actions; avoids a vacuous repair |
| Repaired finite closure | All 470 reachable states satisfy single writer; maximum shortest-path distance is 14 actions |

Depth 8 of the vulnerable model contains 445 states and leaves 183 frontier
rows with omitted successors. Although time is capped, its epochs are not:
at time 4, two unfenced nodes with expired leases can alternate ownership
indefinitely without publishing. The implementation aborts on runtime epoch
overflow instead of wrapping, clamping or silently disabling a valid action.

The reusable [bounded explorer](../../model_check/explore.mbt) records minimum
depths, omitted frontier rows and whether it has exhausted the reachable closure.
It preserves every transition needed for prefixes up to the declared bound.
Hitting the separate state-count resource limit aborts the experiment.
The Z3/TLA+ adapters reject checks beyond a partial graph's depth and reject
liveness checks on partial graphs. No omitted edge is turned into a stutter.
Apalache's deadlock check is disabled for these safety/reachability checks:
the original model allows dead ends, and a cutoff can also omit successors.

The repaired model is explored to depth 16, which exhausts its closure.
Checking every state then covers arbitrary-length executions **of this finite
model**, including self transitions. This is distinct from the depth-8 SMT result.
The clock cap, two-node domain and fixed offsets remain assumptions; this is
not a `moon prove` induction theorem for arbitrary clocks or node counts.

All exported states, guards, successors, predicates and frontier metadata are
compared with a separate imperative reference. A 1,000-case QuickCheck property
uses standard array shrinking. Tests also cover TTL equality, invalid actions,
renewal resurrection, continuing epochs, and forged replay certificates.
Every solver witness is replayed through the actual MoonBit `step`, not just the
exported table. The model, explorer, adapters and tests are executable checks;
no celld implementation correspondence or scheduler fairness is assumed here.
