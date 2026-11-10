///|
/// Shared commands for replayable stack, queue, and priority-queue tests.
#derive(Debug, Eq)
pub(all) enum Command {
  Push(Int32)
  Pop
  Peek
  Clear
}

///|
pub extend Command with @debug.Debug::{to_repr}

///|
pub extend Command with Eq::{not_equal, equal}

///|
/// Array shrinking removes commands; this instance shrinks Push payloads.
pub impl @shrink.Shrink for Command with fn shrink(self) {
  match self {
    Push(value) => @shrink.Shrink::shrink(value).map(smaller => Push(smaller))
    Pop | Peek | Clear => [||]
  }
}

///|
pub extend Command with @shrink.Shrink::{shrink}

///|
pub impl @quickcheck.Arbitrary for Command with fn arbitrary(size, state) {
  match state.next_uint(limit=7U) {
    0..<4 => Push(@quickcheck.Arbitrary::arbitrary(size, state))
    4 => Pop
    5 => Peek
    _ => Clear
  }
}

///|
pub extend Command with @quickcheck.Arbitrary::{arbitrary}
