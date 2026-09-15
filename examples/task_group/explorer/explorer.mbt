///|
/// Faults are test mutations, never part of the proved transition relation.
pub(all) enum Fault {
  Correct
  EarlyJoin
  LeakCleanup
  LostCancel
} derive(Eq, Debug)

///|
pub(all) struct Snapshot {
  phase : Int
  body : Int
  first : Int
  second : Int
  first_held : Bool
  second_held : Bool
  cancel_requested : Bool
  failed : Bool
} derive(ToJson)

///|
pub(all) struct Graph {
  model : @model_check.Model[Snapshot]
  states : Array[@task_group.State]
}

///|
pub using @model_check {type Witness}

///|
pub fn events() -> Array[@task_group.Event] {
  [
    Spawn(First),
    Spawn(Second),
    Complete(First),
    Complete(Second),
    Fail(First),
    Fail(Second),
    CancelTask(First),
    CancelTask(Second),
    Cleanup(First),
    Cleanup(Second),
    BodyReturn,
    BodyFail,
    BodyCancelled,
    CancelGroup,
    ReturnImmediately,
    Join,
    FinishDefers,
    FailDefers,
    Tick,
  ]
}

///|
pub fn policy(mask : Int) -> @task_group.Policy {
  {
    first_no_wait: (mask & 1) != 0,
    second_no_wait: (mask & 2) != 0,
    first_allow_failure: (mask & 4) != 0,
    second_allow_failure: (mask & 8) != 0,
  }
}

///|
pub fn transition(
  policy : @task_group.Policy,
  state : @task_group.State,
  event : @task_group.Event,
  fault : Fault,
) -> @task_group.State? {
  if fault == EarlyJoin && event == Join && state.phase == Closing {
    return Some({ ..state, phase: Finalizing, })
  }
  match @task_group.step(policy, state, event) {
    None => None
    Some(next) =>
      Some(
        match (fault, event) {
          (LeakCleanup, Cleanup(First)) =>
            { ..next, first_held: state.first_held, }
          (LeakCleanup, Cleanup(Second)) =>
            { ..next, second_held: state.second_held, }
          (LostCancel, CancelGroup) => { ..next, second: state.second, }
          _ => next
        },
      )
  }
}

///|
fn child_code(child : @task_group.Child) -> Int {
  match child {
    Absent => 0
    Active => 1
    Completing => 2
    Failing => 3
    Cancelling => 4
    Done => 5
  }
}

///|
fn snapshot(state : @task_group.State) -> Snapshot {
  {
    phase: match state.phase {
      Open => 0
      Closing => 1
      Finalizing => 2
      Returned => 3
    },
    body: match state.body {
      Running => 0
      CancelRequested => 1
      Finished => 2
    },
    first: child_code(state.first),
    second: child_code(state.second),
    first_held: state.first_held,
    second_held: state.second_held,
    cancel_requested: state.cancel_requested,
    failed: state.failed,
  }
}

///|
pub fn holds(state : @task_group.State, name : String) -> Bool {
  match name {
    "safe" => @task_group.safe(state)
    "no_orphans" => @task_group.no_orphans(state)
    "resources" => @task_group.terminal_resources_released(state)
    "closing" => state.phase == Closing || state.phase == Finalizing
    "returned" => state.phase == Returned
    "normal_return" =>
      state.phase == Returned && !state.failed && !state.cancel_requested
    "body_done" => state.body == Finished
    "failed_return" => state.phase == Returned && state.failed
    _ => false
  }
}

///|
/// Enumerate the reachable closure without a depth cutoff. Integer identifiers
/// are assigned by equality of actual immutable MoonBit states.
pub fn explore(policy : @task_group.Policy, fault : Fault) -> Graph {
  let states = [@task_group.initial()]
  let transitions = []
  let choices = events()
  let mut cursor = 0
  while cursor < states.length() {
    let row = []
    for event in choices {
      let code = match transition(policy, states[cursor], event, fault) {
        None => -1
        Some(next) =>
          match states.search_by(s => s == next) {
            Some(index) => index
            None => {
              let index = states.length()
              guard index < 4096 else {
                abort("TaskGroup state space exceeds the explicit-state limit")
              }
              states.push(next)
              index
            }
          }
      }
      row.push(code)
    }
    transitions.push(row)
    cursor += 1
  }
  let predicates = Map([])
  for
    name in [
      "safe", "no_orphans", "resources", "closing", "returned", "body_done", "normal_return",
      "failed_return",
    ] {
    predicates.set(name, states.map(s => holds(s, name)))
  }
  {
    states,
    model: {
      initial: 0,
      actions: [
        "spawn-first", "spawn-second", "complete-first", "complete-second", "fail-first",
        "fail-second", "cancel-first", "cancel-second", "cleanup-first", "cleanup-second",
        "body-return", "body-fail", "body-cancelled", "cancel-group", "return-immediately",
        "join", "finish-defers", "fail-defers", "tick",
      ],
      states: states.map(snapshot),
      transitions,
      predicates,
      justice: [8, 9, 12, 15, 16],
      exploration: None,
    },
  }
}

///|
pub fn Graph::client(
  self : Graph,
  policy : @task_group.Policy,
  fault : Fault,
) -> @model_check.Client[@task_group.State, @task_group.Event, Snapshot] {
  {
    initial: @task_group.initial(),
    states: self.states,
    events: events(),
    model: self.model,
    step: (state, event) => transition(policy, state, event, fault),
    holds: (state, name) => {
      if self.model.predicates.contains(name) {
        Some(holds(state, name))
      } else {
        None
      }
    },
  }
}

///|
/// Compatibility facade; certificate evaluation is shared with other models.
pub fn accepts(
  graph : Graph,
  policy : @task_group.Policy,
  fault : Fault,
  witness : Witness,
  property : String,
  fair : Bool,
) -> Bool {
  let property : @model_check.Property = match property {
    "safe" | "no_orphans" | "resources" => Safety(property)
    "returned" | "normal_return" | "failed_return" => Reachability(property)
    "closing-response" => Response("closing", "returned")
    "body-response" => Response("body_done", "returned")
    _ => return false
  }
  graph
  .client(policy, fault)
  .accepts(
    property,
    witness,
    justice=if fair { graph.model.justice } else { [] },
  )
}
