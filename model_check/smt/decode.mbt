///|
fn is_separator(unit : Int32) -> Bool {
  unit == '(' ||
  unit == ')' ||
  unit == ' ' ||
  unit == '\n' ||
  unit == '\r' ||
  unit == '\t'
}

///|
/// Whether `token` is `prefix` followed by the decimal digits of `index`.
fn is_indexed(token : StringView, prefix : Int32, index : Int32) -> Bool {
  let length = token.length()
  guard length >= 2 && token.unsafe_get(0).to_int() == prefix else {
    return false
  }
  let mut rest = index
  for position = length - 1; position >= 1; position = position - 1 {
    guard token.unsafe_get(position).to_int() == '0' + rest % 10 else {
      return false
    }
    rest = rest / 10
    // No leading zeros: the digits end exactly at the prefix.
    if rest == 0 {
      return position == 1
    }
  }
  false
}

///|
/// A plain decimal numeral below 10^9, or -1 for anything else.
fn small_numeral(token : StringView) -> Int32 {
  let length = token.length()
  guard length >= 1 && length <= 9 else { return -1 }
  let mut value = 0
  for position = 0; position < length; position = position + 1 {
    let digit = token.unsafe_get(position).to_int() - '0'
    guard digit >= 0 && digit <= 9 else { return -1 }
    value = value * 10 + digit
  }
  value
}

///|
/// The common case: bindings in the order `value_command` requested them,
/// with plain numerals. Position alone then identifies each name, so no
/// table is needed. `None` defers to the general decoder, which accepts any
/// order and reports the precise defect.
fn decode_ordered(
  tokens : Array[StringView],
  depth : Int32,
  response : Bool,
) -> @model_check.Witness? {
  let bindings = depth * 2 + 1 + (if response { 1 } else { 0 })
  guard tokens.length() == bindings * 4 + 3 else { return None }
  let states = Array::make(depth + 1, 0)
  let actions = Array::make(depth, 0)
  let mut loop_start = None
  for binding = 0; binding < bindings; binding = binding + 1 {
    let at = 2 + binding * 4
    guard tokens[at] == "(" && tokens[at + 3] == ")" else { return None }
    let value = small_numeral(tokens[at + 2])
    guard value >= 0 else { return None }
    let name = tokens[at + 1]
    if binding <= depth {
      guard is_indexed(name, 's', binding) else { return None }
      states[binding] = value
    } else if binding <= depth * 2 {
      let action = binding - depth - 1
      guard is_indexed(name, 'a', action) else { return None }
      actions[action] = value
    } else {
      guard name == "loop" else { return None }
      loop_start = Some(value)
    }
  }
  Some({ states, actions, loop_start, })
}

///|
/// Only the exact get-value grammar for our nonnegative integer IDs is accepted.
pub fn decode_witness(
  output : String,
  depth : Int32,
  response~ : Bool,
) -> @model_check.Witness raise {
  guard depth >= 0 && depth <= 1000000 else {
    raise InvalidSolverOutput("Invalid depth")
  }
  // Tokens are views into the output: no per-character string building.
  let tokens : Array[StringView] = []
  let length = output.length()
  let mut index = 0
  while index < length {
    let unit = output.unsafe_get(index).to_int()
    if unit == '(' || unit == ')' {
      tokens.push(output.exact_view(start=index, end=index + 1))
      index += 1
    } else if is_separator(unit) {
      index += 1
    } else {
      let start = index
      while index < length && !is_separator(output.unsafe_get(index).to_int()) {
        index += 1
      }
      tokens.push(output.exact_view(start~, end=index))
    }
  }
  guard tokens.length() >= 3 &&
    tokens[0] == "sat" &&
    tokens[1] == "(" &&
    tokens[tokens.length() - 1] == ")" else {
    raise InvalidSolverOutput("Expected sat and values")
  }
  if decode_ordered(tokens, depth, response) is Some(witness) {
    return witness
  }
  let values : Map[StringView, Int32] = Map([])
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
    let value = @string.parse_int(tokens[i + 2])
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
  let key = StringBuilder()
  for i = 0; i <= depth; i = i + 1 {
    key.reset()
    key.write_char('s')
    write_int(key, i)
    states.push(
      match values.get(key.to_string()) {
        Some(v) => v
        None => raise InvalidSolverOutput("Missing state")
      },
    )
  }
  for i = 0; i < depth; i = i + 1 {
    key.reset()
    key.write_char('a')
    write_int(key, i)
    actions.push(
      match values.get(key.to_string()) {
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
  justice~ : Array[Int32] = [],
) -> Bool raise ModelError {
  validate_query(model, property, witness.actions.length(), justice~)
  let client : @model_check.Client[Int32, Int32, Json] = {
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
