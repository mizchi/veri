///|
pub(all) enum TaskId {
  First
  Second
} derive(Eq, Debug, Hash)

///|
pub extend TaskId with Eq::{not_equal, equal}

///|
pub extend TaskId with @debug.Debug::{to_repr}

///|
pub extend TaskId with Hash::{hash, hash_combine}

///|
pub(all) enum Child {
  Absent
  Active
  Completing
  Failing
  Cancelling
  Done
} derive(Eq, Debug, Hash)

///|
pub extend Child with Eq::{not_equal, equal}

///|
pub extend Child with @debug.Debug::{to_repr}

///|
pub extend Child with Hash::{hash, hash_combine}

///|
pub(all) enum Body {
  Running
  CancelRequested
  Finished
} derive(Eq, Debug, Hash)

///|
pub extend Body with Eq::{not_equal, equal}

///|
pub extend Body with @debug.Debug::{to_repr}

///|
pub extend Body with Hash::{hash, hash_combine}

///|
pub(all) enum Phase {
  Open
  Closing
  Finalizing
  Returned
} derive(Eq, Debug, Hash)

///|
pub extend Phase with Eq::{not_equal, equal}

///|
pub extend Phase with @debug.Debug::{to_repr}

///|
pub extend Phase with Hash::{hash, hash_combine}

///|
pub(all) struct Policy {
  first_no_wait : Bool
  second_no_wait : Bool
  first_allow_failure : Bool
  second_allow_failure : Bool
} derive(Eq, Debug, Hash)

///|
pub extend Policy with Eq::{not_equal, equal}

///|
pub extend Policy with @debug.Debug::{to_repr}

///|
pub extend Policy with Hash::{hash, hash_combine}

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
} derive(Eq, Debug, Hash)

///|
pub extend State with Eq::{not_equal, equal}

///|
pub extend State with @debug.Debug::{to_repr}

///|
pub extend State with Hash::{hash, hash_combine}

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
} derive(Eq, Debug, Hash)

///|
pub extend Event with Eq::{not_equal, equal}

///|
pub extend Event with @debug.Debug::{to_repr}

///|
pub extend Event with Hash::{hash, hash_combine}
