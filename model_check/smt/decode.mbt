///|
/// Only the exact get-value grammar for our nonnegative integer IDs is accepted.
pub fn decode_witness(
  output : String,
  depth : Int,
  response~ : Bool,
) -> @model_check.Witness raise {
  guard depth >= 0 && depth <= 1000000 else {
    raise InvalidSolverOutput("Invalid depth")
  }
  let tokens = []
  let mut atom = ""
  for c in output {
    if c == '(' || c == ')' || c == ' ' || c == '\n' || c == '\r' || c == '\t' {
      if !atom.is_empty() {
        tokens.push(atom)
        atom = ""
      }
      if c == '(' || c == ')' {
        tokens.push(c.to_string())
      }
    } else {
      atom += c.to_string()
    }
  }
  if !atom.is_empty() {
    tokens.push(atom)
  }
  guard tokens.length() >= 3 &&
    tokens[0] == "sat" &&
    tokens[1] == "(" &&
    tokens[tokens.length() - 1] == ")" else {
    raise InvalidSolverOutput("Expected sat and values")
  }
  let values : Map[String, Int] = Map([])
  let mut i = 2
  while i < tokens.length() - 1 {
    guard i + 3 < tokens.length() - 1 &&
      tokens[i] == "(" &&
      tokens[i + 3] == ")" else {
      raise InvalidSolverOutput("Malformed binding")
    }
    let name = tokens[i + 1]
    guard !values.contains(name) else {
      raise InvalidSolverOutput("Duplicate binding")
    }
    let value = @string.parse_int(tokens[i + 2][:])
    guard value >= 0 else {
      raise InvalidSolverOutput("Negative state/action ID")
    }
    values.set(name, value)
    i += 4
  }
  guard i == tokens.length() - 1 &&
    values.length() == depth * 2 + 1 + (if response { 1 } else { 0 }) else {
    raise InvalidSolverOutput("Binding count")
  }
  let states = []
  let actions = []
  for i = 0; i <= depth; i = i + 1 {
    states.push(
      match values.get("s\{i}") {
        Some(v) => v
        None => raise InvalidSolverOutput("Missing state")
      },
    )
  }
  for i = 0; i < depth; i = i + 1 {
    actions.push(
      match values.get("a\{i}") {
        Some(v) => v
        None => raise InvalidSolverOutput("Missing action")
      },
    )
  }
  let loop_start = if response {
    Some(
      match values.get("loop") {
        Some(v) => v
        None => raise InvalidSolverOutput("Missing loop")
      },
    )
  } else {
    None
  }
  { states, actions, loop_start, }
}

///|
/// Evaluate a decoded solver trace against the graph before invoking the driver.
pub fn evaluate(
  model : @model_check.Model[Json],
  property : @model_check.Property,
  witness : @model_check.Witness,
  justice? : Array[Int] = [],
) -> Bool raise ModelError {
  validate_query(model, property, witness.actions.length(), justice~)
  let client : @model_check.Client[Int, Int, Json] = {
    initial: model.initial,
    states: Array::makei(model.states.length(), i => i),
    events: Array::makei(model.actions.length(), i => i),
    model,
    step: (s, a) => {
      let next = model.transitions[s][a]
      if next < 0 {
        None
      } else {
        Some(next)
      }
    },
    holds: (s, name) => model.predicates.get(name).map(flags => flags[s]),
  }
  client.accepts(property, witness, justice~)
}
