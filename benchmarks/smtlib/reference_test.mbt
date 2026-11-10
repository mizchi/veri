// The encoder and decoder as they were before tuning (release 0.2.1), kept
// verbatim apart from names. They are the oracle the tuned implementation
// must match byte for byte, and the baseline its timings are compared with.

///|
fn reference_all(parts : Array[String]) -> String {
  if parts.is_empty() {
    "true"
  } else {
    "(and " + parts.join(" ") + ")"
  }
}

///|
fn reference_any(parts : Array[String]) -> String {
  if parts.is_empty() {
    "false"
  } else {
    "(or " + parts.join(" ") + ")"
  }
}

///|
fn reference_symbols(model : @model_check.Model[Json]) -> Map[String, String] {
  let result = Map([])
  let names = model.predicates.keys().to_array()
  names.sort()
  for i, name in names {
    result.set(name, "p" + i.to_string())
  }
  result
}

///|
fn reference_at(
  symbols : Map[String, String],
  name : String,
  i : Int32,
) -> String {
  "(" + symbols.get(name).unwrap() + " s" + i.to_string() + ")"
}

///|
/// Shared definitions and initial state, sent once to an incremental solver.
fn reference_initial_source(
  model : @model_check.Model[Json],
) -> String raise @mc_smt.ModelError {
  @mc_smt.validate(model)
  let lines = ["(set-logic QF_UFLIA)", "(declare-fun next (Int Int) Int)"]
  for s, row in model.transitions {
    for a, next in row {
      lines.push("(assert (= (next \{s} \{a}) \{next}))")
    }
  }
  let names = reference_symbols(model)
  for name, flags in model.predicates {
    let members = []
    for s, flag in flags {
      if flag {
        members.push("(= s \{s})")
      }
    }
    lines.push(
      "(define-fun " +
      names.get(name).unwrap() +
      " ((s Int)) Bool " +
      reference_any(members) +
      ")",
    )
  }
  lines.push("(declare-const s0 Int)")
  lines.push("(assert (= s0 \{model.initial}))")
  lines.join("\n") + "\n"
}

///|
/// Add one transition permanently, after popping the previous property's scope.
fn reference_step_source(
  model : @model_check.Model[Json],
  i : Int32,
) -> String raise @mc_smt.ModelError {
  guard i >= 0 && i < 1000000 else {
    raise @mc_smt.InvalidQuery("Invalid step index")
  }
  "(declare-const s\{i + 1} Int)\n" +
  "(assert (and (<= 0 s\{i + 1}) (< s\{i + 1} \{model.states.length()})))\n" +
  "(declare-const a\{i} Int)\n" +
  "(assert (and (<= 0 a\{i}) (< a\{i} \{model.actions.length()})))\n" +
  "(assert (= s\{i + 1} (next s\{i} a\{i})))\n"
}

///|
/// Property-local definitions and assertions. The caller owns push/pop scopes.
fn reference_condition_source(
  model : @model_check.Model[Json],
  property : @model_check.Property,
  depth : Int32,
  justice~ : Array[Int32] = [],
) -> String raise @mc_smt.ModelError {
  @mc_smt.validate_query(model, property, depth, justice~)
  let names = reference_symbols(model)
  let lines = []
  let condition = match property {
    Safety(name) =>
      reference_any(
        Array::makei(depth + 1, i => {
          "(not " + reference_at(names, name, i) + ")"
        }),
      )
    Reachability(name) => reference_at(names, name, depth)
    Deadlock(terminal) => {
      let excluded = model.exploration
        .map(scope => scope.frontier)
        .unwrap_or([])
      let flags = model.predicates.get(terminal).unwrap()
      let states = []
      for s, row in model.transitions {
        if !flags[s] && !excluded.contains(s) && row.all(next => next < 0) {
          states.push("(= s \{s})")
        }
      }
      lines.push(
        "(define-fun deadlocked ((s Int)) Bool " + reference_any(states) + ")",
      )
      "(deadlocked s\{depth})"
    }
    Response(trigger, goal) => {
      lines.push("(declare-const loop Int)")
      // Suffix goals are shared, making the lasso formula quadratic rather than cubic.
      lines.push("(define-fun clear\{depth} () Bool true)")
      for i = depth - 1; i >= 0; i = i - 1 {
        lines.push(
          "(define-fun clear\{i} () Bool (and (not " +
          reference_at(names, goal, i) +
          ") clear\{i + 1}))",
        )
      }
      let starts = Array::makei(depth, i => {
        "(and " + reference_at(names, trigger, i) + " clear\{i})"
      })
      let loops = []
      for l = 0; l < depth; l = l + 1 {
        let parts = [
          "(= loop \{l})",
          "(= s\{depth} s\{l})",
          "clear\{l}",
          reference_any(starts),
        ]
        for action in justice {
          let progress = []
          for i = l; i < depth; i = i + 1 {
            progress.push("(< (next s\{i} \{action}) 0)")
            progress.push("(= (next s\{i} \{action}) s\{i})")
            progress.push("(and (= a\{i} \{action}) (not (= s\{i} s\{i + 1})))")
          }
          parts.push(reference_any(progress))
        }
        loops.push(reference_all(parts))
      }
      reference_any(loops)
    }
  }
  lines.push("(assert " + condition + ")")
  lines.join("\n") + "\n"
}

///|
/// Standalone encoding retained for differential tests and external solvers.
fn reference_query_source(
  model : @model_check.Model[Json],
  property : @model_check.Property,
  depth : Int32,
  justice~ : Array[Int32] = [],
) -> String raise @mc_smt.ModelError {
  @mc_smt.validate_query(model, property, depth, justice~)
  let parts = [reference_initial_source(model)]
  for i = 0; i < depth; i = i + 1 {
    parts.push(reference_step_source(model, i))
  }
  parts.push(reference_condition_source(model, property, depth, justice~))
  parts.join("")
}

///|
/// Only the exact get-value grammar for our nonnegative integer IDs is accepted.
fn reference_decode_witness(
  output : String,
  depth : Int32,
  response~ : Bool,
) -> @model_check.Witness raise {
  guard depth >= 0 && depth <= 1000000 else {
    raise @mc_smt.InvalidSolverOutput("Invalid depth")
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
    raise @mc_smt.InvalidSolverOutput("Expected sat and values")
  }
  let values : Map[String, Int32] = Map([])
  let mut i = 2
  while i < tokens.length() - 1 {
    guard i + 3 < tokens.length() - 1 &&
      tokens[i] == "(" &&
      tokens[i + 3] == ")" else {
      raise @mc_smt.InvalidSolverOutput("Malformed binding")
    }
    let name = tokens[i + 1]
    guard !values.contains(name) else {
      raise @mc_smt.InvalidSolverOutput("Duplicate binding")
    }
    let value = @string.parse_int(tokens[i + 2][:])
    guard value >= 0 else {
      raise @mc_smt.InvalidSolverOutput("Negative state/action ID")
    }
    values.set(name, value)
    i += 4
  }
  guard i == tokens.length() - 1 &&
    values.length() == depth * 2 + 1 + (if response { 1 } else { 0 }) else {
    raise @mc_smt.InvalidSolverOutput("Binding count")
  }
  let states = []
  let actions = []
  for i = 0; i <= depth; i = i + 1 {
    states.push(
      match values.get("s\{i}") {
        Some(v) => v
        None => raise @mc_smt.InvalidSolverOutput("Missing state")
      },
    )
  }
  for i = 0; i < depth; i = i + 1 {
    actions.push(
      match values.get("a\{i}") {
        Some(v) => v
        None => raise @mc_smt.InvalidSolverOutput("Missing action")
      },
    )
  }
  let loop_start = if response {
    Some(
      match values.get("loop") {
        Some(v) => v
        None => raise @mc_smt.InvalidSolverOutput("Missing loop")
      },
    )
  } else {
    None
  }
  { states, actions, loop_start, }
}
