///|
pub(all) struct Snapshot {
  pending : Bool
  done : Bool
} derive(ToJson)

///|
/// Retain the four-state Boolean domain and the identifiers used by the proofs.
pub fn client(
  allow_drop : Bool,
) -> @model_check.Client[@temporal.State, @temporal.Action, Snapshot] {
  let states = Array::makei(4, code => @temporal.state_from_code(code).unwrap())
  let events : Array[@temporal.Action] = [Request, Complete, Wait, Drop]
  let step = (state, action) => {
    if action == @temporal.Drop && !allow_drop {
      None
    } else {
      @temporal.step(state, action)
    }
  }
  let model : @model_check.Model[Snapshot] = {
    initial: @temporal.state_code(@temporal.initial()),
    actions: ["Request", "Complete", "Wait", "Drop"],
    states: states.map(s => { pending: s.pending, done: s.done, }),
    transitions: states.map(state => {
      events.map(event => {
        match step(state, event) {
          None => -1
          Some(next) => @temporal.state_code(next)
        }
      })
    }),
    predicates: {
      "pending": states.map(s => s.pending),
      "done": states.map(s => s.done),
      "safe": states.map(@temporal.safe),
    },
    justice: [1],
    exploration: None,
  }
  {
    initial: @temporal.initial(),
    states,
    events,
    step,
    model,
    holds: (state, name) => {
      match name {
        "pending" => Some(state.pending)
        "done" => Some(state.done)
        "safe" => Some(@temporal.safe(state))
        _ => None
      }
    },
  }
}
