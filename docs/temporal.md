# Temporal model checking

[日本語](temporal.ja.md) | [README](../README.md)

## Temporal checking experiment

`just temporal` runs a fixed job model with Z3: inductive safety, a liveness
counterexample with indefinite waiting, and weak-fairness checks including a lost
request. Bounded lasso checks report absence of a counterexample at the chosen
bound, not an unbounded temporal proof. SAT traces are also replayed against an
independent finite-state model. See [the experiment](../checks/temporal/README.md).
`just verify-temporal` also
proves the shared MoonBit transition and arbitrary finite-trace safety, exports
its actual finite transition table to Z3, and replays counterexamples in MoonBit.
This is a development PoC, not a general public temporal API.

`just verify-task-group` checks a TaskGroup model with two children and its body:
`no_wait`, `allow_failure`, cancellation, joining and group cleanup. It combines
`moon prove`, Z3 response checks, shrinking QuickCheck, and observed traces from
the real `moonbitlang/async@0.21.3` runtime. Runtime correspondence is tested,
not proved. See [TaskGroup usage and boundaries](../checks/task_group/README.md).

`just apalache` installs pinned Apalache 0.62.2 and Java 21 through Nix, compares
15 Job/TaskGroup checks with Z3 through depth 8, and replays witnesses in MoonBit.
Logs, generated TLA+ and ITF traces are under `_build/apalache`. This optional
backend checks finite models; absence of a bounded counterexample is not an
unbounded liveness proof.

All three models use the [shared client and driver](../model_check/README.md).
Connect another model through MoonBit's `Client` and `serve`, then use
`moonx veri.mbtx` to export it, check it with Z3, and replay certificates without Node.js.
For example: `moonx veri.mbtx check lease_clock/driver --module examples --config '{"variant":0,"bound":8}' --safety single_writer --bound 8`.
Run `just verify-model-check` to check the common API and existing models.

`just verify-lease-clock` checks the [Quint lease-clock port](../examples/lease_clock/README.md).
It reproduces the four-action two-writer trace and exhausts all 470 reachable
states of the repaired finite model. `just apalache-lease-clock` also compares
the bounded checks with Apalache. This example models the protocol only.
