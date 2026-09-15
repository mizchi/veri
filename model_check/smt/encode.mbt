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
fn at(symbols : Map[String, String], name : String, i : Int) -> String {
  "(" + symbols.get(name).unwrap() + " s" + i.to_string() + ")"
}

///|
/// Predicate names are mapped to generated symbols; no model text becomes SMT code.
pub fn query_source(
  model : @model_check.Model[Json],
  property : @model_check.Property,
  depth : Int,
  justice? : Array[Int] = [],
) -> String raise ModelError {
  validate_query(model, property, depth, justice~)
  let lines = ["(set-logic QF_UFLIA)", "(declare-fun next (Int Int) Int)"]
  for s, row in model.transitions {
    for a, next in row {
      lines.push("(assert (= (next \{s} \{a}) \{next}))")
    }
  }
  let symbols : Map[String, String] = Map([])
  for name, flags in model.predicates {
    let symbol = "p" + symbols.length().to_string()
    symbols.set(name, symbol)
    let members = []
    for s, flag in flags {
      if flag {
        members.push("(= s \{s})")
      }
    }
    lines.push("(define-fun \{symbol} ((s Int)) Bool " + any(members) + ")")
  }
  for i = 0; i <= depth; i = i + 1 {
    lines.push("(declare-const s\{i} Int)")
    lines.push("(assert (and (<= 0 s\{i}) (< s\{i} \{model.states.length()})))")
  }
  lines.push("(assert (= s0 \{model.initial}))")
  for i = 0; i < depth; i = i + 1 {
    lines.push("(declare-const a\{i} Int)")
    lines.push(
      "(assert (and (<= 0 a\{i}) (< a\{i} \{model.actions.length()})))",
    )
    lines.push("(assert (= s\{i + 1} (next s\{i} a\{i})))")
  }
  let condition = match property {
    Safety(name) =>
      any(Array::makei(depth + 1, i => "(not " + at(symbols, name, i) + ")"))
    Reachability(name) => at(symbols, name, depth)
    Response(trigger, goal) => {
      lines.push("(declare-const loop Int)")
      let loops = []
      for loop_index = 0; loop_index < depth; loop_index = loop_index + 1 {
        let violations = []
        for start = 0; start < depth; start = start + 1 {
          let parts = [at(symbols, trigger, start)]
          for i = start; i < depth; i = i + 1 {
            parts.push("(not " + at(symbols, goal, i) + ")")
          }
          for i = loop_index; i < depth; i = i + 1 {
            parts.push("(not " + at(symbols, goal, i) + ")")
          }
          violations.push(all(parts))
        }
        let parts = [
          "(= loop \{loop_index})",
          "(= s\{depth} s\{loop_index})",
          any(violations),
        ]
        for action in justice {
          let progress = []
          for i = loop_index; i < depth; i = i + 1 {
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
