///|
priv enum Scenario {
  Normal
  NoWait
  Failure
  AllowedFailure
  ManualCancel
  Immediate
  ExternalCancel
  BodyFailure
  DeferFailure
} derive(Eq)

///|
suberror WorkerError

///|
priv struct Monitor {
  policy : @task_group.Policy
  mut state : @task_group.State
  trace : Array[@task_group.Event]
}

///|
fn Monitor::observe(self : Monitor, event : @task_group.Event) -> Unit {
  match @task_group.step(self.policy, self.state, event) {
    None =>
      abort(
        "Runtime trace violates TaskGroup model: \{@debug.to_string(event)}, \{@debug.to_string(self.state)}",
      )
    Some(next) => self.state = next
  }
  self.trace.push(event)
}

///|
async fn exercise(scenario : Scenario, reverse : Bool) -> Unit {
  let policy : @task_group.Policy = {
    first_no_wait: false,
    second_no_wait: scenario == NoWait,
    first_allow_failure: scenario == AllowedFailure,
    second_allow_failure: false,
  }
  let monitor = { policy, state: @task_group.initial(), trace: [], }
  let held = [false, false]
  let cleaned = [false, false]
  let commands : Array[@aqueue.Queue[Bool]] = [
    @aqueue.Queue(kind=Blocking(1)),
    @aqueue.Queue(kind=Blocking(1)),
  ]
  let ready : @aqueue.Queue[Int] = @aqueue.Queue(kind=Blocking(1))
  let external_ready : @aqueue.Queue[Unit] = @aqueue.Queue(kind=Blocking(1))
  let block : @aqueue.Queue[Unit] = @aqueue.Queue(kind=Blocking(1))
  let order = if reverse { [1, 0] } else { [0, 1] }
  let defer_order = []
  let mut actual_failed = false
  let mut actual_cancelled = false
  @async.with_task_group(supervisor => {
    let task = supervisor.spawn(() => {
      @async.with_task_group(group => {
        // Group defers run in reverse registration order, after child defers.
        group.add_defer(() => {
          defer_order.push(1)
          if scenario == DeferFailure {
            monitor.observe(FailDefers)
            raise WorkerError
          }
          monitor.observe(FinishDefers)
        })
        group.add_defer(() => {
          assert_true(cleaned[0] && cleaned[1])
          assert_false(held[0] || held[1])
          monitor.observe(Join)
          defer_order.push(2)
        })
        defer (if @async.is_being_cancelled() {
          monitor.observe(BodyCancelled)
        })
        let handles : Array[@async.Task[Unit]?] = [None, None]
        for index in order {
          let id : @task_group.TaskId = if index == 0 { First } else { Second }
          monitor.observe(Spawn(id))
          handles[index] = Some(
            group.spawn(
              no_wait=index == 1 && scenario == NoWait,
              allow_failure=index == 0 && scenario == AllowedFailure,
              () => {
                held[index] = true
                defer {
                  held[index] = false
                  cleaned[index] = true
                  monitor.observe(Cleanup(id))
                }
                ready.put(index)
                if commands[index].get() {
                  monitor.observe(Complete(id))
                } else {
                  monitor.observe(Fail(id))
                  raise WorkerError
                }
              },
            ),
          )
        }
        // Handshakes, not sleeps: both children have acquired their resource
        // and reached a cancellable wait before the scenario starts.
        ignore(ready.get())
        ignore(ready.get())
        match scenario {
          Normal | AllowedFailure | DeferFailure => {
            for index in order {
              commands[index].put(index != 0 || scenario != AllowedFailure)
            }
            monitor.observe(BodyReturn)
          }
          NoWait => {
            commands[0].put(true)
            monitor.observe(BodyReturn)
          }
          Failure => {
            commands[0].put(false)
            block.get()
          }
          ManualCancel => {
            monitor.observe(CancelTask(First))
            handles[0].unwrap().cancel()
            commands[1].put(true)
            monitor.observe(BodyReturn)
          }
          Immediate => {
            monitor.observe(ReturnImmediately)
            group.return_immediately(())
          }
          ExternalCancel => {
            external_ready.put(())
            block.get()
          }
          BodyFailure => {
            monitor.observe(BodyFail)
            raise WorkerError
          }
        }
      }) catch {
        err => {
          actual_cancelled = @async.is_cancellation_error(err)
          if !actual_cancelled {
            guard err is WorkerError else { raise err }
            actual_failed = true
          }
        }
      }
    })
    if scenario == ExternalCancel {
      external_ready.get()
      monitor.observe(CancelGroup)
      task.cancel()
    }
  })
  assert_eq(
    actual_failed,
    scenario == Failure || scenario == BodyFailure || scenario == DeferFailure,
  )
  assert_eq(actual_cancelled, scenario == ExternalCancel)
  assert_eq(defer_order, [2, 1])
  assert_true(cleaned[0] && cleaned[1])
  assert_false(held[0] || held[1])
  assert_eq(monitor.state.phase, Returned)
  assert_eq(monitor.state.failed, actual_failed)
  assert_eq(monitor.state.cancel_requested, scenario == ExternalCancel)
  assert_eq(
    @task_group.replay(
      policy,
      @task_group.initial(),
      @list.List::from_iter(monitor.trace.iter()),
    ),
    Some(monitor.state),
  )
}

///|
async test "real TaskGroup traces follow the model across exit and failure modes" {
  @async.with_timeout(5000, () => {
    for
      scenario in [
        Normal,
        NoWait,
        Failure,
        AllowedFailure,
        ManualCancel,
        Immediate,
        ExternalCancel,
        BodyFailure,
        DeferFailure,
      ] {
      exercise(scenario, false)
      exercise(scenario, true)
    }
  })
}
