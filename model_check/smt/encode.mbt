// Queries are written straight into one buffer. Their size is linear in the
// model and quadratic in the depth for response properties, so intermediate
// strings per clause would dominate encoding time.

///|
/// Decimal text of 0..999, and the same zero-padded to three digits. State,
/// action and step indices are written through these tables: one append of
/// an existing string each, which is fast on every backend (the JavaScript
/// builder appends strings far more cheaply than single characters).
let decimals : FixedArray[String] = FixedArray::makei(1000, i => i.to_string())

///|
let padded : FixedArray[String] = FixedArray::makei(1000, i => {
  if i < 10 {
    "00" + i.to_string()
  } else if i < 100 {
    "0" + i.to_string()
  } else {
    i.to_string()
  }
})

///|
fn write_int(out : StringBuilder, value : Int32) -> Unit {
  if value < 0 {
    out.write_string(value.to_string())
  } else if value < 1000 {
    out.write_string(decimals[value])
  } else {
    write_int(out, value / 1000)
    out.write_string(padded[value % 1000])
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
/// `(p sI)`, the predicate `symbol` at step `i`.
fn write_at(out : StringBuilder, symbol : String, i : Int32) -> Unit {
  out.write_string("(")
  out.write_string(symbol)
  out.write_string(" s")
  write_int(out, i)
  out.write_string(")")
}

///|
fn write_initial(out : StringBuilder, model : @model_check.Model[Json]) -> Unit {
  out.write_string("(set-logic QF_UFLIA)\n(declare-fun next (Int Int) Int)\n")
  for s, row in model.transitions {
    for a, next in row {
      out.write_string("(assert (= (next ")
      write_int(out, s)
      out.write_string(" ")
      write_int(out, a)
      out.write_string(") ")
      write_int(out, next)
      out.write_string("))\n")
    }
  }
  let names = symbols(model)
  for name, flags in model.predicates {
    out.write_string("(define-fun ")
    out.write_string(names.get(name).unwrap())
    out.write_string(" ((s Int)) Bool ")
    let mut members = 0
    for s, flag in flags {
      if flag {
        out.write_string(if members == 0 { "(or (= s " } else { " (= s " })
        write_int(out, s)
        out.write_string(")")
        members += 1
      }
    }
    out.write_string(if members == 0 { "false)\n" } else { "))\n" })
  }
  out.write_string("(declare-const s0 Int)\n(assert (= s0 ")
  write_int(out, model.initial)
  out.write_string("))\n")
}

///|
/// Shared definitions and initial state, sent once to an incremental solver.
pub fn initial_source(
  model : @model_check.Model[Json],
) -> String raise ModelError {
  validate(model)
  let out = StringBuilder()
  write_initial(out, model)
  out.to_string()
}

///|
fn write_step(
  out : StringBuilder,
  model : @model_check.Model[Json],
  i : Int32,
) -> Unit {
  out.write_string("(declare-const s")
  write_int(out, i + 1)
  out.write_string(" Int)\n(assert (and (<= 0 s")
  write_int(out, i + 1)
  out.write_string(") (< s")
  write_int(out, i + 1)
  out.write_string(" ")
  write_int(out, model.states.length())
  out.write_string(")))\n(declare-const a")
  write_int(out, i)
  out.write_string(" Int)\n(assert (and (<= 0 a")
  write_int(out, i)
  out.write_string(") (< a")
  write_int(out, i)
  out.write_string(" ")
  write_int(out, model.actions.length())
  out.write_string(")))\n(assert (= s")
  write_int(out, i + 1)
  out.write_string(" (next s")
  write_int(out, i)
  out.write_string(" a")
  write_int(out, i)
  out.write_string(")))\n")
}

///|
/// Add one transition permanently, after popping the previous property's scope.
pub fn step_source(
  model : @model_check.Model[Json],
  i : Int32,
) -> String raise ModelError {
  guard i >= 0 && i < 1000000 else { raise InvalidQuery("Invalid step index") }
  let out = StringBuilder()
  write_step(out, model, i)
  out.to_string()
}

///|
/// The query must already be validated.
fn write_condition(
  out : StringBuilder,
  model : @model_check.Model[Json],
  property : @model_check.Property,
  depth : Int32,
  justice : Array[Int32],
) -> Unit {
  let names = symbols(model)
  match property {
    Safety(name) => {
      let symbol = names.get(name).unwrap()
      out.write_string("(assert (or")
      for i = 0; i <= depth; i = i + 1 {
        out.write_string(" (not ")
        write_at(out, symbol, i)
        out.write_string(")")
      }
      out.write_string("))\n")
    }
    Reachability(name) => {
      out.write_string("(assert ")
      write_at(out, names.get(name).unwrap(), depth)
      out.write_string(")\n")
    }
    Deadlock(terminal) => {
      let excluded = model.exploration
        .map(scope => scope.frontier)
        .unwrap_or([])
      let flags = model.predicates.get(terminal).unwrap()
      out.write_string("(define-fun deadlocked ((s Int)) Bool ")
      let mut members = 0
      for s, row in model.transitions {
        if !flags[s] && !excluded.contains(s) && row.all(next => next < 0) {
          out.write_string(if members == 0 { "(or (= s " } else { " (= s " })
          write_int(out, s)
          out.write_string(")")
          members += 1
        }
      }
      out.write_string(if members == 0 { "false)\n" } else { "))\n" })
      out.write_string("(assert (deadlocked s")
      write_int(out, depth)
      out.write_string("))\n")
    }
    Response(trigger, goal) => {
      let trigger = names.get(trigger).unwrap()
      let goal = names.get(goal).unwrap()
      out.write_string("(declare-const loop Int)\n(define-fun clear")
      write_int(out, depth)
      out.write_string(" () Bool true)\n")
      // Suffix goals are shared, making the lasso formula quadratic rather than cubic.
      for i = depth - 1; i >= 0; i = i - 1 {
        out.write_string("(define-fun clear")
        write_int(out, i)
        out.write_string(" () Bool (and (not ")
        write_at(out, goal, i)
        out.write_string(") clear")
        write_int(out, i + 1)
        out.write_string("))\n")
      }
      // Every loop start repeats the same trigger disjunction: build it once.
      let starts = StringBuilder()
      if depth == 0 {
        starts.write_string("false")
      } else {
        starts.write_string("(or")
        for i = 0; i < depth; i = i + 1 {
          starts.write_string(" (and ")
          write_at(starts, trigger, i)
          starts.write_string(" clear")
          write_int(starts, i)
          starts.write_string(")")
        }
        starts.write_string(")")
      }
      let starts = starts.to_string()
      if depth == 0 {
        out.write_string("(assert false)\n")
        return
      }
      out.write_string("(assert (or")
      for l = 0; l < depth; l = l + 1 {
        out.write_string(" (and (= loop ")
        write_int(out, l)
        out.write_string(") (= s")
        write_int(out, depth)
        out.write_string(" s")
        write_int(out, l)
        out.write_string(") clear")
        write_int(out, l)
        out.write_string(" ")
        out.write_string(starts)
        for action in justice {
          // `l < depth`, so each progress disjunction has at least one step.
          out.write_string(" (or")
          for i = l; i < depth; i = i + 1 {
            out.write_string(" (< (next s")
            write_int(out, i)
            out.write_string(" ")
            write_int(out, action)
            out.write_string(") 0) (= (next s")
            write_int(out, i)
            out.write_string(" ")
            write_int(out, action)
            out.write_string(") s")
            write_int(out, i)
            out.write_string(") (and (= a")
            write_int(out, i)
            out.write_string(" ")
            write_int(out, action)
            out.write_string(") (not (= s")
            write_int(out, i)
            out.write_string(" s")
            write_int(out, i + 1)
            out.write_string(")))")
          }
          out.write_string(")")
        }
        out.write_string(")")
      }
      out.write_string("))\n")
    }
  }
}

///|
/// Property-local definitions and assertions. The caller owns push/pop scopes.
pub fn condition_source(
  model : @model_check.Model[Json],
  property : @model_check.Property,
  depth : Int32,
  justice~ : Array[Int32] = [],
) -> String raise ModelError {
  validate_query(model, property, depth, justice~)
  let out = StringBuilder()
  write_condition(out, model, property, depth, justice)
  out.to_string()
}

///|
/// Standalone encoding retained for differential tests and external solvers.
pub fn query_source(
  model : @model_check.Model[Json],
  property : @model_check.Property,
  depth : Int32,
  justice~ : Array[Int32] = [],
) -> String raise ModelError {
  // One validation covers the three parts written below.
  validate_query(model, property, depth, justice~)
  let out = StringBuilder()
  write_initial(out, model)
  for i = 0; i < depth; i = i + 1 {
    write_step(out, model, i)
  }
  write_condition(out, model, property, depth, justice)
  out.to_string()
}

///|
pub fn value_command(depth : Int32, response~ : Bool) -> String {
  let out = StringBuilder()
  out.write_string("(get-value (s0")
  for i = 1; i <= depth; i = i + 1 {
    out.write_string(" s")
    write_int(out, i)
  }
  for i = 0; i < depth; i = i + 1 {
    out.write_string(" a")
    write_int(out, i)
  }
  if response {
    out.write_string(" loop")
  }
  out.write_string("))\n")
  out.to_string()
}
