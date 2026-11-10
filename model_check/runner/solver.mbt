///|
fn validate_limits(limits : @model_check.Limits) -> Unit raise RunnerError {
  guard limits.timeout_ms > 0 &&
    limits.memory_mb > 0 &&
    limits.max_query_bytes > 0 &&
    limits.max_output_bytes > 0 else {
    raise InvalidResponse("All resource limits must be positive")
  }
}

///|
/// One structured process per property, retaining definitions and path prefixes.
/// Timeout, malformed output, and exceptions cancel the process and close pipes.
async fn solve(
  model : @model_check.Model[Json],
  property : @model_check.Property,
  bound : Int32,
  justice : Array[Int32],
  z3 : String,
  limits : @model_check.Limits,
) -> @model_check.Witness? {
  validate_limits(limits)
  @solver.with_session(
    z3~,
    timeout_ms=limits.timeout_ms,
    memory_mb=limits.memory_mb,
    max_query_bytes=limits.max_query_bytes,
    max_output_bytes=limits.max_output_bytes,
    session => {
      session.send(@smt.initial_source(model))
      let response = property is @model_check.Response(_, _)
      for depth = 0; depth <= bound; depth = depth + 1 {
        if depth > 0 {
          session.send(@smt.step_source(model, depth - 1))
        }
        if response && depth == 0 {
          continue
        }
        session.send(
          "(push 1)\n" +
          @smt.condition_source(model, property, depth, justice~) +
          "(check-sat)\n",
        )
        let status = session.line()
        match status {
          "unsat" => session.send("(pop 1)\n")
          "sat" => {
            session.send(@smt.value_command(depth, response~))
            return Some(
              @smt.decode_witness(
                "sat\n" + session.response(),
                depth,
                response~,
              ),
            )
          }
          _ => raise SolverFailure("Expected sat or unsat, got: " + status)
        }
      }
      None
    },
  ) catch {
    @solver.SolverFailure(message) => raise SolverFailure(message)
    error => raise error
  }
}
