///|
pub(all) struct Snapshot {
  now : Int
  a : @lease_clock.NodeState
  b : @lease_clock.NodeState
  owner : Int
  epoch : Int
} derive(ToJson)

///|
pub(all) struct Graph {
  model : @model_check.Model[Snapshot]
  states : Array[@lease_clock.State]
}

///|
pub using @model_check {type Witness}

///|
fn definition(
  variant : @lease_clock.Variant,
) -> @model_check.Spec[@lease_clock.State, @lease_clock.Event, Snapshot] {
  let labels = [
    "advance-time", "renew-a", "renew-b", "fence-a", "fence-b", "take-over-a", "take-over-b",
    "publish-owner",
  ]
  let events = @lease_clock.events()
  {
    initial: @lease_clock.initial(),
    actions: Array::makei(events.length(), i => (labels[i], events[i])),
    step: (state, event) => @lease_clock.step(variant, state, event),
    predicates: [
      ("single_writer", s => @lease_clock.single_writer(variant, s)),
      ("b_writer", s => @lease_clock.may_write(variant, s, B)),
    ],
    snapshot: s => {
      now: s.now,
      a: s.a,
      b: s.b,
      owner: if s.owner == A {
        0
      } else {
        1
      },
      epoch: s.epoch,
    },
    justice: [],
  }
}

///|
pub fn explore(
  variant : @lease_clock.Variant,
  bound : Int,
  max_states? : Int = 4096,
) -> Graph raise {
  let client = @model_check.build_client(
    definition(variant),
    max_depth=bound,
    max_states~,
    state_hash=state => state.hash(),
  )
  { states: client.states, model: client.model, }
}

///|
pub fn Graph::client(
  self : Graph,
  variant : @lease_clock.Variant,
) -> @model_check.Client[@lease_clock.State, @lease_clock.Event, Snapshot] {
  let spec = definition(variant)
  {
    initial: @lease_clock.initial(),
    states: self.states,
    events: @lease_clock.events(),
    model: self.model,
    step: (state, event) => @lease_clock.step(variant, state, event),
    holds: (state, name) => spec.holds(state, name),
  }
}

///|
/// Compatibility facade; certificate evaluation is shared with other models.
pub fn accepts(
  graph : Graph,
  variant : @lease_clock.Variant,
  property : String,
  witness : Witness,
) -> Bool {
  let property : @model_check.Property = match property {
    "single_writer" => Safety(property)
    "b_writer" => Reachability(property)
    _ => return false
  }
  graph.client(variant).accepts(property, witness)
}
