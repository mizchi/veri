///|
pub(all) struct Snapshot {
  pending : Bool
  done : Bool
} derive(ToJson)

///|
/// Preserve the state identifiers used by the proof clients.
pub fn client(
  allow_drop : Bool,
) -> @model_check.Client[@temporal.State, @temporal.Action, Snapshot] {
  let spec : @model_check.Spec[@temporal.State, @temporal.Action, Snapshot] = {
    initial: @temporal.initial(),
    actions: [
      ("Request", Request),
      ("Complete", Complete),
      ("Wait", Wait),
      ("Drop", Drop),
    ],
    step: (state, action) => {
      if action == @temporal.Drop && !allow_drop {
        None
      } else {
        @temporal.step(state, action)
      }
    },
    predicates: [
      ("pending", s => s.pending),
      ("done", s => s.done),
      ("safe", @temporal.safe),
    ],
    snapshot: s => { pending: s.pending, done: s.done, },
    justice: ["Complete"],
  }
  @model_check.client_from_states(
    spec,
    Array::makei(4, code => @temporal.state_from_code(code).unwrap()),
  ) catch {
    _ => abort("Invalid Job definition")
  }
}
