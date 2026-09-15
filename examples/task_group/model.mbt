///|
#proof_pure
fn initial_model() -> State {
  {
    phase: Open,
    body: Running,
    first: Absent,
    second: Absent,
    first_held: false,
    second_held: false,
    cancel_requested: false,
    failed: false,
  }
}

///|
#proof_pure
fn terminal(child : Child) -> Bool {
  match child {
    Absent | Done => true
    _ => false
  }
}

///|
#proof_pure
fn body_finished(body : Body) -> Bool {
  match body {
    Finished => true
    _ => false
  }
}

///|
#proof_pure
fn child_model(state : State, task : TaskId) -> Child {
  match task {
    First => state.first
    Second => state.second
  }
}

///|
#proof_pure
fn set_child(state : State, task : TaskId, child : Child, held : Bool) -> State {
  match task {
    First =>
      {
        phase: state.phase,
        body: state.body,
        first: child,
        second: state.second,
        first_held: held,
        second_held: state.second_held,
        cancel_requested: state.cancel_requested,
        failed: state.failed,
      }
    Second =>
      {
        phase: state.phase,
        body: state.body,
        first: state.first,
        second: child,
        first_held: state.first_held,
        second_held: held,
        cancel_requested: state.cancel_requested,
        failed: state.failed,
      }
  }
}

///|
#proof_pure
fn cancel_child(child : Child) -> Child {
  match child {
    Active => Cancelling
    _ => child
  }
}

///|
#proof_pure
fn close_model(state : State, failed : Bool) -> State {
  {
    phase: Closing,
    body: match state.body {
      Running => CancelRequested
      _ => state.body
    },
    first: cancel_child(state.first),
    second: cancel_child(state.second),
    first_held: state.first_held,
    second_held: state.second_held,
    cancel_requested: state.cancel_requested,
    failed: state.failed || failed,
  }
}

///|
/// The body counts as a waited child. no_wait children are cancelled only when
/// the last waited task has finished, then must still be joined.
#proof_pure
fn settle(policy : Policy, state : State) -> State {
  match state.phase {
    Open =>
      if body_finished(state.body) &&
        (policy.first_no_wait || terminal(state.first)) &&
        (policy.second_no_wait || terminal(state.second)) {
        close_model(state, false)
      } else {
        state
      }
    _ => state
  }
}

///|
#proof_pure
fn no_orphans_model(state : State) -> Bool {
  match state.phase {
    Finalizing | Returned =>
      body_finished(state.body) &&
      terminal(state.first) &&
      terminal(state.second)
    _ => true
  }
}

///|
#proof_pure
fn resources_model(state : State) -> Bool {
  (!terminal(state.first) || !state.first_held) &&
  (!terminal(state.second) || !state.second_held)
}

///|
#proof_pure
fn invariant_model(state : State) -> Bool {
  no_orphans_model(state) &&
  resources_model(state) &&
  (match state.phase {
    Closing =>
      (match state.body {
        Running => false
        _ => true
      }) &&
      (match state.first {
        Active => false
        _ => true
      }) &&
      (match state.second {
        Active => false
        _ => true
      })
    _ => true
  })
}

///|
/// Each child has one lifetime and a conceptual resource released by Cleanup.
/// Completing/Failing retain the resource until defer has run.
#proof_pure
fn step_model(policy : Policy, state : State, event : Event) -> State? {
  match event {
    Tick => Some(state)
    Spawn(task) => {
      let can_spawn = match state.phase {
        Open => true
        Closing =>
          !body_finished(state.body) ||
          !terminal(state.first) ||
          !terminal(state.second)
        _ => false
      }
      match child_model(state, task) {
        Absent =>
          if can_spawn {
            let child = match state.phase {
              Open => Active
              _ => Cancelling
            }
            Some(set_child(state, task, child, true))
          } else {
            None
          }
        _ => None
      }
    }
    Complete(task) | Fail(task) =>
      match child_model(state, task) {
        Active =>
          Some(
            set_child(
              state,
              task,
              match event {
                Complete(_) => Completing
                _ => Failing
              },
              match task {
                First => state.first_held
                Second => state.second_held
              },
            ),
          )
        _ => None
      }
    CancelTask(task) =>
      match child_model(state, task) {
        Absent => None
        child =>
          Some(
            set_child(
              state,
              task,
              cancel_child(child),
              match task {
                First => state.first_held
                Second => state.second_held
              },
            ),
          )
      }
    Cleanup(task) =>
      match child_model(state, task) {
        Completing | Failing | Cancelling => {
          let fatal = match child_model(state, task) {
            Failing =>
              match task {
                First => !policy.first_allow_failure
                Second => !policy.second_allow_failure
              }
            _ => false
          }
          let next = set_child(state, task, Done, false)
          Some(
            if fatal {
              close_model(next, true)
            } else {
              settle(policy, next)
            },
          )
        }
        _ => None
      }
    BodyReturn =>
      match state.body {
        Running =>
          Some(
            settle(policy, {
              phase: state.phase,
              body: Finished,
              first: state.first,
              second: state.second,
              first_held: state.first_held,
              second_held: state.second_held,
              cancel_requested: state.cancel_requested,
              failed: state.failed,
            }),
          )
        _ => None
      }
    BodyFail =>
      match state.body {
        Running =>
          Some(
            close_model(
              {
                phase: state.phase,
                body: Finished,
                first: state.first,
                second: state.second,
                first_held: state.first_held,
                second_held: state.second_held,
                cancel_requested: state.cancel_requested,
                failed: state.failed,
              },
              true,
            ),
          )
        _ => None
      }
    BodyCancelled =>
      match state.body {
        CancelRequested =>
          Some({
            phase: state.phase,
            body: Finished,
            first: state.first,
            second: state.second,
            first_held: state.first_held,
            second_held: state.second_held,
            cancel_requested: state.cancel_requested,
            failed: state.failed,
          })
        _ => None
      }
    CancelGroup | ReturnImmediately =>
      match state.phase {
        Open =>
          Some(
            close_model(
              match event {
                CancelGroup => mark_cancel_requested(state)
                _ => state
              },
              false,
            ),
          )
        _ => None
      }
    Join =>
      match state.phase {
        Closing =>
          if body_finished(state.body) &&
            terminal(state.first) &&
            terminal(state.second) {
            Some({
              phase: Finalizing,
              body: state.body,
              first: state.first,
              second: state.second,
              first_held: state.first_held,
              second_held: state.second_held,
              cancel_requested: state.cancel_requested,
              failed: state.failed,
            })
          } else {
            None
          }
        _ => None
      }
    FinishDefers | FailDefers =>
      match state.phase {
        Finalizing =>
          Some({
            phase: Returned,
            body: state.body,
            first: state.first,
            second: state.second,
            first_held: state.first_held,
            second_held: state.second_held,
            cancel_requested: state.cancel_requested,
            failed: state.failed ||
            (match event {
              FailDefers => true
              _ => false
            }),
          })
        _ => None
      }
  }
}

///|
#proof_pure
fn mark_cancel_requested(state : State) -> State {
  {
    phase: state.phase,
    body: state.body,
    first: state.first,
    second: state.second,
    first_held: state.first_held,
    second_held: state.second_held,
    cancel_requested: true,
    failed: state.failed,
  }
}
