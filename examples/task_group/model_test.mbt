///|
fn execute(
  policy : @task_group.Policy,
  events : Array[@task_group.Event],
) -> @task_group.State {
  let mut state = @task_group.initial()
  for event in events {
    state = @task_group.step(policy, state, event).unwrap()
  }
  state
}

///|
test "body return waits for child cleanup and group defers" {
  let policy = @task_group.default_policy()
  let waiting = execute(policy, [Spawn(First), Spawn(Second), BodyReturn])
  assert_eq(waiting.phase, Open)
  assert_eq(@task_group.step(policy, waiting, Join), None)
  let closing = execute(policy, [
    Spawn(First),
    Spawn(Second),
    BodyReturn,
    Complete(First),
    Cleanup(First),
    Complete(Second),
    Cleanup(Second),
  ])
  assert_eq(closing.phase, Closing)
  let defers = @task_group.step(policy, closing, Join).unwrap()
  assert_eq(defers.phase, Finalizing)
  assert_eq(
    @task_group.step(policy, defers, FinishDefers).unwrap().phase,
    Returned,
  )
}

///|
test "no_wait still cancels and joins the child" {
  let policy = { ..@task_group.default_policy(), second_no_wait: true, }
  let state = execute(policy, [
    Spawn(First),
    Spawn(Second),
    BodyReturn,
    Complete(First),
    Cleanup(First),
  ])
  assert_eq(state.phase, Closing)
  assert_eq(state.second, Cancelling)
  assert_true(state.second_held)
  assert_eq(@task_group.step(policy, state, Join), None)
  let clean = @task_group.step(policy, state, Cleanup(Second)).unwrap()
  assert_false(clean.second_held)
  assert_eq(@task_group.step(policy, clean, Join).unwrap().phase, Finalizing)
}

///|
test "failure propagates after cleanup; allow_failure isolates it" {
  let policy = @task_group.default_policy()
  let failing = execute(policy, [Spawn(First), Spawn(Second), Fail(First)])
  assert_false(failing.failed)
  let state = @task_group.step(policy, failing, Cleanup(First)).unwrap()
  assert_true(state.failed)
  assert_eq(state.body, CancelRequested)
  assert_eq(state.second, Cancelling)
  let isolated = @task_group.step(
    { ..policy, first_allow_failure: true, },
    failing,
    Cleanup(First),
  ).unwrap()
  assert_false(isolated.failed)
  assert_eq(isolated.phase, Open)
  assert_eq(isolated.second, Active)
}

///|
test "return_immediately requests cancellation but does not return the group" {
  let policy = @task_group.default_policy()
  let closing = execute(policy, [Spawn(First), Spawn(Second), ReturnImmediately])
  assert_eq(closing.phase, Closing)
  assert_eq(closing.body, CancelRequested)
  assert_eq(@task_group.step(policy, closing, Join), None)
  let done = execute(policy, [
    Spawn(First),
    Spawn(Second),
    ReturnImmediately,
    Cleanup(Second),
    BodyCancelled,
    Cleanup(First),
    Join,
    FinishDefers,
  ])
  assert_eq(done.phase, Returned)
  assert_false(done.failed)
  assert_false(done.first_held || done.second_held)
}

///|
test "manual cancellation is not failure; closed group rejects spawn" {
  let policy = @task_group.default_policy()
  let state = execute(policy, [
    Spawn(First),
    CancelTask(First),
    Cleanup(First),
    BodyReturn,
    Join,
    FinishDefers,
  ])
  assert_false(state.failed)
  assert_eq(@task_group.step(policy, state, Spawn(Second)), None)
}

///|
test "external group cancellation remains distinct from successful early return" {
  let policy = @task_group.default_policy()
  let cancelled = execute(policy, [
    CancelGroup,
    BodyCancelled,
    Join,
    FinishDefers,
  ])
  let early = execute(policy, [
    ReturnImmediately,
    BodyCancelled,
    Join,
    FinishDefers,
  ])
  assert_true(cancelled.cancel_requested)
  assert_false(early.cancel_requested)
  assert_false(cancelled.failed || early.failed)
}

///|
test "spawn during cancellation starts cancelled; group defers cannot spawn" {
  let policy = @task_group.default_policy()
  let closing = execute(policy, [Spawn(First), CancelGroup, Spawn(Second)])
  assert_eq(closing.second, Cancelling)
  let defers = execute(policy, [CancelGroup, BodyCancelled, Join])
  assert_eq(@task_group.step(policy, defers, Spawn(First)), None)
  assert_true(@task_group.step(policy, defers, FailDefers).unwrap().failed)
}

///|
test "quickcheck: schedules preserve resources and compose with proved replay, with shrinking" {
  let events : Array[@task_group.Event] = [
    Spawn(First),
    Spawn(Second),
    Complete(First),
    Complete(Second),
    Fail(First),
    Fail(Second),
    CancelTask(First),
    CancelTask(Second),
    Cleanup(First),
    Cleanup(Second),
    BodyReturn,
    BodyFail,
    BodyCancelled,
    CancelGroup,
    ReturnImmediately,
    Join,
    FinishDefers,
    FailDefers,
    Tick,
  ]
  @quickcheck.check(
    (input : (Int, Array[Int])) => {
      let (mask, schedule) = input
      let policy : @task_group.Policy = {
        first_no_wait: (mask & 1) != 0,
        second_no_wait: (mask & 2) != 0,
        first_allow_failure: (mask & 4) != 0,
        second_allow_failure: (mask & 8) != 0,
      }
      let mut state = @task_group.initial()
      let selected = []
      for raw in schedule {
        let available = events.filter(e => {
          @task_group.step(policy, state, e) is Some(_)
        })
        let event = available[(raw % available.length()).abs()]
        state = @task_group.step(policy, state, event).unwrap()
        selected.push(event)
        if !@task_group.safe(state) ||
          !@task_group.no_orphans(state) ||
          !@task_group.terminal_resources_released(state) {
          return false
        }
      }
      @task_group.replay(
        policy,
        @task_group.initial(),
        @list.List::from_iter(selected.iter()),
      ) ==
      Some(state)
    },
    count=1000,
    max_size=80,
    max_shrinks=1000,
    seed=20260929,
  )
}
