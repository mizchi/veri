///|
/// A ring with one shortcut action: every state has successors, and the
/// predicates select sparse subsets so every query retains real content.
fn ring(states : Int32) -> @model_check.Model[Json] {
  {
    initial: 0,
    actions: ["advance", "skip", "stay"],
    states: Array::makei(states, i => Json::number(i.to_double())),
    transitions: Array::makei(states, i => {
      [(i + 1) % states, (i + 7) % states, i]
    }),
    predicates: {
      "safe": Array::makei(states, i => i % 97 != 96),
      "pending": Array::makei(states, i => i % 5 == 1),
      "done": Array::makei(states, i => i % 5 == 4),
    },
    justice: [0],
    exploration: None,
  }
}

///|
/// A solver answer for `value_command(depth, response=true)`, laid out as Z3
/// prints it: one binding per line.
fn witness_output(depth : Int32) -> String {
  let out = StringBuilder()
  out.write_string("sat\n(")
  for i in 0..<=depth {
    out.write_string("(s\{i} \{i * 7})\n ")
  }
  for i in 0..<depth {
    out.write_string("(a\{i} 1)\n ")
  }
  out.write_string("(loop 3))")
  out.to_string()
}

///|
/// Benchmarked closures cannot raise; every fixture here is valid.
fn[T] must(f : () -> T raise) -> T {
  f() catch {
    _ => panic()
  }
}

///|
/// The runner's protocol: one step and one scoped condition per depth.
fn incremental(
  depth : Int32,
  step : (Int32) -> String,
  condition : (Int32) -> String,
) -> String {
  let parts = []
  for i in 0..<=depth {
    if i > 0 {
      parts.push(step(i - 1))
    }
    parts.push(condition(i))
  }
  parts.join("")
}

///|
fn model_check_workloads() -> Array[Workload] {
  let workloads = []
  for states in [256, 2048] {
    let model = ring(states)
    workloads.push(
      Workload::compare(
        "model_check/initial-source|states=\{states}",
        () => must(() => reference_initial_source(model)),
        () => must(() => @mc_smt.initial_source(model)),
      ),
    )
  }
  let model = ring(256)
  let response : @model_check.Property = Response("pending", "done")
  let safety : @model_check.Property = Safety("safe")
  for depth in [16, 64] {
    workloads.push(
      Workload::compare(
        "model_check/response-query|depth=\{depth}",
        () => {
          must(() => reference_query_source(model, response, depth, justice=[0]))
        },
        () => {
          must(() => @mc_smt.query_source(model, response, depth, justice=[0]))
        },
      ),
    )
    workloads.push(
      Workload::compare(
        "model_check/incremental-safety|depth=\{depth}",
        () => {
          incremental(depth, i => must(() => reference_step_source(model, i)), i => {
            must(() => reference_condition_source(model, safety, i))
          })
        },
        () => {
          incremental(depth, i => must(() => @mc_smt.step_source(model, i)), i => {
            must(() => @mc_smt.condition_source(model, safety, i))
          })
        },
      ),
    )
  }
  for depth in [64, 1024] {
    let output = witness_output(depth)
    workloads.push(
      Workload::compare(
        "model_check/decode-witness|depth=\{depth}",
        () => {
          must(() => {
            reference_decode_witness(output, depth, response=true)
            .to_json()
            .stringify()
          })
        },
        () => {
          must(() => {
            @mc_smt.decode_witness(output, depth, response=true)
            .to_json()
            .stringify()
          })
        },
        // Serializing the witness is for the equality check only.
        timed_reference=() => {
          must(() => {
            reference_decode_witness(output, depth, response=true).states.length()
          })
        },
        timed_tuned=() => {
          must(() => {
            @mc_smt.decode_witness(output, depth, response=true).states.length()
          })
        },
      ),
    )
  }
  workloads
}
