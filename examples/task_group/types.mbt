///|
pub(all) enum TaskId {
  First
  Second
} derive(Eq, Debug)

///|
pub(all) enum Child {
  Absent
  Active
  Completing
  Failing
  Cancelling
  Done
} derive(Eq, Debug)

///|
pub(all) enum Body {
  Running
  CancelRequested
  Finished
} derive(Eq, Debug)

///|
pub(all) enum Phase {
  Open
  Closing
  Finalizing
  Returned
} derive(Eq, Debug)

///|
pub(all) struct Policy {
  first_no_wait : Bool
  second_no_wait : Bool
  first_allow_failure : Bool
  second_allow_failure : Bool
} derive(Eq, Debug)

///|
pub(all) struct State {
  phase : Phase
  body : Body
  first : Child
  second : Child
  first_held : Bool
  second_held : Bool
  cancel_requested : Bool
  failed : Bool
} derive(Eq, Debug)

///|
pub(all) enum Event {
  Spawn(TaskId)
  Complete(TaskId)
  Fail(TaskId)
  CancelTask(TaskId)
  Cleanup(TaskId)
  BodyReturn
  BodyFail
  BodyCancelled
  CancelGroup
  ReturnImmediately
  Join
  FinishDefers
  FailDefers
  Tick
} derive(Eq, Debug)
