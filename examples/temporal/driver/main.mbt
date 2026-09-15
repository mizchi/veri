///|
struct Model {
  initial : Int
  action_names : Array[String]
  pending : Array[Bool]
  done : Array[Bool]
  transitions : Array[Array[Int]]
} derive(ToJson)

///|
struct Witness {
  states : Array[Int]
  actions : Array[Int]
  loop_start : Int
  allow_drop : Bool
  fair : Bool
} derive(@json.FromJson)

///|
fn actions() -> Array[@temporal.Action] {
  [Request, Complete, Wait, Drop]
}

///|
/// Enumerate the complete Boolean state domain, including the unreachable state.
/// The transition table comes from the actual contracted MoonBit step function.
fn export_model() -> Model {
  let pending = []
  let done = []
  let transitions = []
  for code = 0; code < 4; code = code + 1 {
    let state = @temporal.state_from_code(code).unwrap()
    pending.push(state.pending)
    done.push(state.done)
    transitions.push(
      actions().map(action => {
        match @temporal.step(state, action) {
          None => -1
          Some(next) => @temporal.state_code(next)
        }
      }),
    )
  }
  {
    initial: @temporal.state_code(@temporal.initial()),
    action_names: ["Request", "Complete", "Wait", "Drop"],
    pending,
    done,
    transitions,
  }
}

///|
/// Test the solver's certificate by executing step, not by consulting its table.
/// This IO adapter/lasso evaluator is tested, not included in the implementation proof.
fn check_witness(witness : Witness) -> Bool {
  let states = witness.states
  let count = witness.actions.length()
  if count == 0 || states.length() - 1 != count {
    return false
  }
  let loop_start = witness.loop_start
  if loop_start < 0 ||
    loop_start >= count ||
    states[0] != @temporal.state_code(@temporal.initial()) ||
    states[count] != states[loop_start] {
    return false
  }
  let choices = actions()
  let mut fair_loop = false
  for i = 0; i < count; i = i + 1 {
    let action = witness.actions[i]
    if action < 0 ||
      action >= choices.length() ||
      (!witness.allow_drop && action == 3) {
      return false
    }
    let state = match @temporal.state_from_code(states[i]) {
      None => return false
      Some(state) => state
    }
    match @temporal.step(state, choices[action]) {
      None => return false
      Some(next) =>
        if @temporal.state_code(next) != states[i + 1] {
          return false
        }
    }
    if i >= loop_start && (!@temporal.enabled(state, Complete) || action == 1) {
      fair_loop = true
    }
  }
  if witness.fair && !fair_loop {
    return false
  }
  for start = 0; start < count; start = start + 1 {
    if !@temporal.state_from_code(states[start]).unwrap().pending {
      continue
    }
    let mut no_completion = true
    for j = start; j < count; j = j + 1 {
      if @temporal.state_from_code(states[j]).unwrap().done {
        no_completion = false
      }
    }
    for j = loop_start; j < count; j = j + 1 {
      if @temporal.state_from_code(states[j]).unwrap().done {
        no_completion = false
      }
    }
    if no_completion {
      return true
    }
  }
  false
}

///|
fn main {
  let argument = @env.args().last().unwrap()
  if argument == "export" {
    println(@json.to_json(export_model()).stringify())
  } else {
    let input : Array[Witness] = try! @json.from_json(@json.parse(argument[:]))
    println(input.map(check_witness).to_json().stringify())
  }
}
