///|
fn all(parts : Array[String]) -> String {
  if parts.is_empty() {
    "true"
  } else {
    "(and " + parts.join(" ") + ")"
  }
}

///|
fn any(parts : Array[String]) -> String {
  if parts.is_empty() {
    "false"
  } else {
    "(or " + parts.join(" ") + ")"
  }
}

///|
fn symbols(model : @model_check.Model[Json]) -> Map[String, String] {
  let result = Map([])
  let names = model.predicates.keys().to_array()
  names.sort()
  for i, name in names {
    result.set(name, "p" + i.to_string())
  }
  result
}

///|
fn at(symbols : Map[String, String], name : String, i : Int) -> String {
  "(" + symbols.get(name).unwrap() + " s" + i.to_string() + ")"
}

///|
/// Shared definitions and initial state, sent once to an incremental solver.
pub fn initial_source(
  model : @model_check.Model[Json],
) -> String raise ModelError {
  validate(model)
  let lines = ["(set-logic QF_UFLIA)", "(declare-fun next (Int Int) Int)"]
  for s, row in model.transitions {
    for a, next in row {
      lines.push("(assert (= (next \{s} \{a}) \{next}))")
    }
  }
  let names = symbols(model)
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
      any(members) +
      ")",
    )
  }
  lines.push("(declare-const s0 Int)")
  lines.push("(assert (= s0 \{model.initial}))")
  lines.join("\n") + "\n"
}

///|
/// Add one transition permanently, after popping the previous property's scope.
pub fn step_source(
  model : @model_check.Model[Json],
  i : Int,
) -> String raise ModelError {
  guard i >= 0 && i < 1000000 else { raise InvalidQuery("Invalid step index") }
  "(declare-const s\{i + 1} Int)\n" +
  "(assert (and (<= 0 s\{i + 1}) (< s\{i + 1} \{model.states.length()})))\n" +
  "(declare-const a\{i} Int)\n" +
  "(assert (and (<= 0 a\{i}) (< a\{i} \{model.actions.length()})))\n" +
  "(assert (= s\{i + 1} (next s\{i} a\{i})))\n"
}

///|
/// Property-local definitions and assertions. The caller owns push/pop scopes.
pub fn condition_source(
  model : @model_check.Model[Json],
  property : @model_check.Property,
  depth : Int,
  justice? : Array[Int] = [],
) -> String raise ModelError {
  validate_query(model, property, depth, justice~)
  let names = symbols(model)
  let lines = []
  let condition = match property {
    Safety(name) =>
      any(Array::makei(depth + 1, i => "(not " + at(names, name, i) + ")"))
    Reachability(name) => at(names, name, depth)
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
      lines.push("(define-fun deadlocked ((s Int)) Bool " + any(states) + ")")
      "(deadlocked s\{depth})"
    }
    Response(trigger, goal) => {
      lines.push("(declare-const loop Int)")
      // Suffix goals are shared, making the lasso formula quadratic rather than cubic.
      lines.push("(define-fun clear\{depth} () Bool true)")
      for i = depth - 1; i >= 0; i = i - 1 {
        lines.push(
          "(define-fun clear\{i} () Bool (and (not " +
          at(names, goal, i) +
          ") clear\{i + 1}))",
        )
      }
      let starts = Array::makei(depth, i => {
        "(and " + at(names, trigger, i) + " clear\{i})"
      })
      let loops = []
      for l = 0; l < depth; l = l + 1 {
        let parts = [
          "(= loop \{l})",
          "(= s\{depth} s\{l})",
          "clear\{l}",
          any(starts),
        ]
        for action in justice {
          let progress = []
          for i = l; i < depth; i = i + 1 {
            progress.push("(< (next s\{i} \{action}) 0)")
            progress.push("(= (next s\{i} \{action}) s\{i})")
            progress.push("(and (= a\{i} \{action}) (not (= s\{i} s\{i + 1})))")
          }
          parts.push(any(progress))
        }
        loops.push(all(parts))
      }
      any(loops)
    }
  }
  lines.push("(assert " + condition + ")")
  lines.join("\n") + "\n"
}

///|
/// Standalone encoding retained for differential tests and external solvers.
pub fn query_source(
  model : @model_check.Model[Json],
  property : @model_check.Property,
  depth : Int,
  justice? : Array[Int] = [],
) -> String raise ModelError {
  validate_query(model, property, depth, justice~)
  let parts = [initial_source(model)]
  for i = 0; i < depth; i = i + 1 {
    parts.push(step_source(model, i))
  }
  parts.push(condition_source(model, property, depth, justice~))
  parts.join("")
}

///|
pub fn value_command(depth : Int, response~ : Bool) -> String {
  let names = Array::makei(depth + 1, i => "s\{i}")
  for i = 0; i < depth; i = i + 1 {
    names.push("a\{i}")
  }
  if response {
    names.push("loop")
  }
  "(get-value (" + names.join(" ") + "))\n"
}
