///|
priv struct OutputBudget {
  mut used : Int
  limit : Int
}

///|
fn OutputBudget::consume(
  self : OutputBudget,
  size : Int,
) -> Unit raise RunnerError {
  guard size <= self.limit - self.used else {
    raise SolverFailure("Solver output budget exceeded")
  }
  self.used += size
}

///|
priv struct Solver {
  reader : @process.ReadFromProcess
  writer : @process.WriteToProcess
  limits : @model_check.Limits
  mut buffer : String
  budget : OutputBudget
  mut bytes_written : Int
}

///|
async fn Solver::send(self : Solver, source : String) -> Unit {
  // SMT generated here is ASCII, so its String length is its byte count.
  guard source.length() <= self.limits.max_query_bytes - self.bytes_written else {
    raise SolverFailure("SMT query budget exceeded")
  }
  self.bytes_written += source.length()
  self.writer.write(source)
}

///|
async fn Solver::line(self : Solver) -> String {
  while true {
    if self.buffer.find("\n") is Some(index) {
      let line = self.buffer[:index].to_owned()
      self.buffer = self.buffer[index + 1:].to_owned()
      return line.trim().to_owned()
    }
    let chunk = match self.reader.read_some(max_len=4096) {
      None => raise SolverFailure("Unexpected solver EOF")
      Some(bytes) => bytes
    }
    self.budget.consume(chunk.length())
    let data : &@io.Data = chunk
    self.buffer += data.text()
  } nobreak {
    raise SolverFailure("Unexpected line reader exit")
  }
}

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
  bound : Int,
  justice : Array[Int],
  z3 : String,
  limits : @model_check.Limits,
) -> @model_check.Witness? {
  validate_limits(limits)
  @async.with_timeout(limits.timeout_ms, () => {
    @async.with_task_group() <| group => {
      let (input, writer) = @process.write_to_process()
      defer writer.close()
      let (reader, output) = @process.read_from_process()
      defer reader.close()
      let (errors, stderr) = @process.read_from_process()
      defer errors.close()
      let budget : OutputBudget = { used: 0, limit: limits.max_output_bytes, }
      group.spawn_bg(() => {
        while errors.read_some(max_len=4096) is Some(chunk) {
          budget.consume(chunk.length())
        }
      })
      let child = @process.spawn(
        group,
        z3[:],
        ["-in", "-smt2", "memory_max_size=\{limits.memory_mb}"],
        stdin=input,
        stdout=output,
        stderr~,
        cancel_handler=@process.hard_cancel(),
        no_wait=true,
      )
      let solver : Solver = {
        reader,
        writer,
        limits,
        buffer: "",
        budget,
        bytes_written: 0,
      }
      solver.send(@smt.initial_source(model))
      let response = property is @model_check.Response(_, _)
      let mut result : @model_check.Witness? = None
      for depth = 0; depth <= bound; depth = depth + 1 {
        if depth > 0 {
          solver.send(@smt.step_source(model, depth - 1))
        }
        if response && depth == 0 {
          continue
        }
        solver.send(
          "(push 1)\n" +
          @smt.condition_source(model, property, depth, justice~) +
          "(check-sat)\n",
        )
        let status = solver.line()
        match status {
          "unsat" => solver.send("(pop 1)\n")
          "sat" => {
            solver.send(
              @smt.value_command(depth, response~) + "(echo \"VERI-END\")\n",
            )
            let lines = ["sat"]
            while true {
              let line = solver.line()
              if line == "VERI-END" {
                break
              }
              lines.push(line)
            }
            result = Some(
              @smt.decode_witness(lines.join("\n"), depth, response~),
            )
            break
          }
          _ => raise SolverFailure("Expected sat or unsat, got: " + status)
        }
      }
      solver.send("(exit)\n")
      guard child.wait() == 0 else {
        raise SolverFailure("Solver exited unsuccessfully")
      }
      result
    }
  })
}
