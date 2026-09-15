///|
/// Test adapter for differential checking of SMT encodings on arbitrary small graphs.
fn main {
  @model_driver.serve((model : @model_check.Model[Json]) => {
    @smt.validate(model)
    let client : @model_check.Client[Int, Int, Json] = {
      initial: model.initial,
      states: Array::makei(model.states.length(), i => i),
      events: Array::makei(model.actions.length(), i => i),
      model,
      step: (state, event) => {
        let next = model.transitions[state][event]
        if next < 0 {
          None
        } else {
          Some(next)
        }
      },
      holds: (state, name) => {
        model.predicates.get(name).map(flags => flags[state])
      },
    }
    client
  })
}
