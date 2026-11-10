///|
#derive(Debug)
pub(all) suberror SolverError {
  /// The solver process misbehaved, or a resource budget was exceeded.
  SolverFailure(String)
}

///|
pub extend SolverError with @debug.Debug::{to_repr}

///|
priv struct Budget {
  mut used : Int32
  limit : Int32
}

///|
fn Budget::consume(self : Budget, size : Int32) -> Unit raise SolverError {
  guard size <= self.limit - self.used else {
    raise SolverFailure("Solver output budget exceeded")
  }
  self.used += size
}

///|
/// One interactive solver process speaking SMT-LIB 2 over pipes.
///
/// Reading is linear in the output size: the current chunk is scanned in
/// place and only an answer that spans chunks is accumulated.
pub struct Session {
  priv reader : @process.ReadFromProcess
  priv writer : @process.WriteToProcess
  priv budget : Budget
  priv max_query_bytes : Int32
  priv mut bytes_written : Int32
  priv mut chunk : String
  priv mut position : Int32
  priv partial : StringBuilder
}

///|
/// Send commands. The text must be ASCII, as everything `smtlib.Script`
/// writes is, so its length is its byte count.
pub async fn Session::send(self : Session, source : String) -> Unit {
  guard source.length() <= self.max_query_bytes - self.bytes_written else {
    raise SolverFailure("SMT query budget exceeded")
  }
  self.bytes_written += source.length()
  self.writer.write(source)
}

///|
/// The next output line, without its terminator or surrounding whitespace.
pub async fn Session::line(self : Session) -> String {
  self.partial.reset()
  while true {
    let chunk = self.chunk
    let start = self.position
    let mut end = start
    while end < chunk.length() && chunk.unsafe_get(end) != '\n' {
      end += 1
    }
    if end < chunk.length() {
      self.position = end + 1
      if self.partial.is_empty() {
        return chunk.exact_view(start~, end~).trim().to_owned()
      }
      self.partial.write_substring(chunk, start, end - start)
      return self.partial.to_string().trim().to_owned()
    }
    self.partial.write_substring(chunk, start, end - start)
    let bytes = match self.reader.read_some(max_len=65536) {
      None => raise SolverFailure("Unexpected solver EOF")
      Some(bytes) => bytes
    }
    self.budget.consume(bytes.length())
    let data : &@io.Data = bytes
    self.chunk = data.text()
    self.position = 0
  } nobreak {
    raise SolverFailure("Unexpected line reader exit")
  }
}

///|
/// Parenthesis depth after `line`, starting from `depth`. String literals
/// and quoted symbols may contain parentheses; neither spans lines in the
/// answers of the supported fragment.
fn nesting(line : String, depth : Int32) -> Int32 {
  let mut depth = depth
  let mut quote = 0
  for index in 0..<line.length() {
    let unit = line.unsafe_get(index).to_int()
    if quote != 0 {
      if unit == quote {
        quote = 0
      }
    } else if unit == '"' || unit == '|' {
      quote = unit
    } else if unit == '(' {
      depth += 1
    } else if unit == ')' {
      depth -= 1
    }
  }
  depth
}

///|
/// One complete answer: an atom such as `sat`, or a parenthesized expression
/// that may span several lines, as `get-value` and `get-model` print.
pub async fn Session::response(self : Session) -> String {
  let first = self.line()
  let mut depth = nesting(first, 0)
  if depth <= 0 {
    return first
  }
  let out = StringBuilder()
  out.write_string(first)
  while depth > 0 {
    let next = self.line()
    out.write_char('\n')
    out.write_string(next)
    depth = nesting(next, depth)
  }
  out.to_string()
}

///|
#derive(Eq, Debug)
pub(all) enum Status {
  Sat
  Unsat
  Unknown
}

///|
pub extend Status with Eq::{not_equal, equal}

///|
pub extend Status with @debug.Debug::{to_repr}

///|
/// Send the pending commands of `script` followed by `(check-sat)`.
pub async fn Session::check_sat(
  self : Session,
  script : @smtlib.Script,
) -> Status {
  script.check_sat()
  self.send(script.take())
  match self.line() {
    "sat" => Sat
    "unsat" => Unsat
    "unknown" => Unknown
    other => raise SolverFailure("Expected sat, unsat or unknown: " + other)
  }
}

///|
/// After a `Sat` answer, the solver's values for `terms`, in order.
pub async fn Session::values(
  self : Session,
  ctx : @smtlib.Context,
  script : @smtlib.Script,
  terms : ArrayView[@smtlib.Term],
) -> Array[@smtlib.Value] {
  script.get_value(terms)
  self.send(script.take())
  ctx.parse_values(self.response(), terms)
}

///|
/// Run `f` against a fresh solver process.
///
/// `z3` is the executable; any solver accepting `-in -smt2` and Z3's
/// `memory_max_size` option works. A timeout, a failed budget, or an error
/// from `f` kills the process and closes its pipes. On normal return the
/// solver is asked to exit and must do so successfully.
pub async fn[T] with_session(
  f : async (Session) -> T,
  z3~ : String = "z3",
  timeout_ms~ : Int32 = 30000,
  memory_mb~ : Int32 = 1024,
  max_query_bytes~ : Int32 = 0x400_0000,
  max_output_bytes~ : Int32 = 0x400_0000,
) -> T {
  guard timeout_ms > 0 &&
    memory_mb > 0 &&
    max_query_bytes > 0 &&
    max_output_bytes > 0 else {
    raise SolverFailure("All resource limits must be positive")
  }
  @async.with_timeout(timeout_ms, () => {
    @async.with_task_group() <| group => {
      let (input, writer) = @process.write_to_process()
      defer writer.close()
      let (reader, output) = @process.read_from_process()
      defer reader.close()
      let (errors, stderr) = @process.read_from_process()
      defer errors.close()
      let budget : Budget = { used: 0, limit: max_output_bytes, }
      group.spawn_bg(() => {
        while errors.read_some(max_len=4096) is Some(chunk) {
          budget.consume(chunk.length())
        }
      })
      let child = @process.spawn(
        group,
        z3[:],
        ["-in", "-smt2", "memory_max_size=\{memory_mb}"],
        stdin=input,
        stdout=output,
        stderr~,
        cancel_handler=@process.hard_cancel(),
        no_wait=true,
      )
      let session : Session = {
        reader,
        writer,
        budget,
        max_query_bytes,
        bytes_written: 0,
        chunk: "",
        position: 0,
        partial: StringBuilder(),
      }
      let result = f(session)
      session.send("(exit)\n")
      guard child.wait() == 0 else {
        raise SolverFailure("Solver exited unsuccessfully")
      }
      result
    }
  })
}

///|
/// The answer to a satisfiability query.
#derive(Debug)
pub(all) enum Outcome {
  /// A model assigning every constant the assertions mention.
  Satisfiable(@smtlib.Model)
  Unsatisfiable
  Undetermined
}

///|
pub extend Outcome with @debug.Debug::{to_repr}

///|
/// Decide the conjunction of `assertions` in a fresh solver process.
pub async fn check(
  ctx : @smtlib.Context,
  assertions : ArrayView[@smtlib.Term],
  logic~ : String = "ALL",
  z3~ : String = "z3",
  timeout_ms~ : Int32 = 30000,
) -> Outcome {
  with_session(z3~, timeout_ms~, session => {
    let script = @smtlib.Script::new(ctx, logic~)
    let constants : Array[@smtlib.Term] = []
    for assertion in assertions {
      script.assert_term(assertion)
      for constant in ctx.free_constants(assertion) {
        if !constants.contains(constant) {
          constants.push(constant)
        }
      }
    }
    match session.check_sat(script) {
      Unsat => Unsatisfiable
      Unknown => Undetermined
      Sat => {
        let model = @smtlib.Model::new()
        if !constants.is_empty() {
          let values = session.values(ctx, script, constants)
          for index, constant in constants {
            model.set(ctx.name_of(constant).unwrap(), values[index])
          }
        }
        Satisfiable(model)
      }
    }
  })
}
