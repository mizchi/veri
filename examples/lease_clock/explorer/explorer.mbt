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
pub fn explore(
  variant : @lease_clock.Variant,
  bound : Int,
) -> Graph raise @model_check.ExplorationError {
  let explored = @model_check.explore(
    @lease_clock.initial(),
    @lease_clock.events(),
    (state, event) => @lease_clock.step(variant, state, event),
    max_depth=bound,
  )
  let states = explored.states
  let predicates = Map([])
  predicates.set(
    "single_writer",
    states.map(s => @lease_clock.single_writer(variant, s)),
  )
  predicates.set(
    "b_writer",
    states.map(s => @lease_clock.may_write(variant, s, B)),
  )
  {
    states,
    model: {
      initial: 0,
      actions: [
        "advance-time", "renew-a", "renew-b", "fence-a", "fence-b", "take-over-a",
        "take-over-b", "publish-owner",
      ],
      states: states.map(s => {
        now: s.now,
        a: s.a,
        b: s.b,
        owner: if s.owner == A {
          0
        } else {
          1
        },
        epoch: s.epoch,
      }),
      transitions: explored.transitions,
      predicates,
      justice: [],
      exploration: Some({
        complete: explored.complete,
        max_depth: explored.max_depth,
        depths: explored.depths,
        frontier: explored.frontier,
      }),
    },
  }
}

///|
pub fn Graph::client(
  self : Graph,
  variant : @lease_clock.Variant,
) -> @model_check.Client[@lease_clock.State, @lease_clock.Event, Snapshot] {
  {
    initial: @lease_clock.initial(),
    states: self.states,
    events: @lease_clock.events(),
    model: self.model,
    step: (state, event) => @lease_clock.step(variant, state, event),
    holds: (state, name) => {
      match name {
        "single_writer" => Some(@lease_clock.single_writer(variant, state))
        "b_writer" => Some(@lease_clock.may_write(variant, state, B))
        _ => None
      }
    },
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
