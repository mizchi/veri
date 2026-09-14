///|
/// Shared commands for replayable stack, queue, and priority-queue tests.
pub(all) enum Command {
  Push(Int)
  Pop
  Peek
  Clear
} derive(Debug, Eq)

///|
/// Array shrinking removes commands; this instance shrinks Push payloads.
pub impl @shrink.Shrink for Command with fn shrink(self) {
  match self {
    Push(value) => @shrink.Shrink::shrink(value).map(smaller => Push(smaller))
    Pop | Peek | Clear => [||]
  }
}

///|
pub impl @quickcheck.Arbitrary for Command with fn arbitrary(size, state) {
  match state.next_uint(limit=7U) {
    0..<4 => Push(@quickcheck.Arbitrary::arbitrary(size, state))
    4 => Pop
    5 => Peek
    _ => Clear
  }
}
