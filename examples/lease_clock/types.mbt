///|
#derive(Eq, Debug, Hash)
pub(all) enum Node {
  A
  B
}

///|
pub extend Node with Eq::{not_equal, equal}

///|
pub extend Node with @debug.Debug::{to_repr}

///|
pub extend Node with Hash::{hash, hash_combine}

///|
#derive(Eq, Debug, Hash)
pub(all) enum Variant {
  Vulnerable
  BoundedSkew
}

///|
pub extend Variant with Eq::{not_equal, equal}

///|
pub extend Variant with @debug.Debug::{to_repr}

///|
pub extend Variant with Hash::{hash, hash_combine}

///|
#derive(Eq, Debug, Hash, ToJson)
pub(all) struct NodeState {
  expires : Int32
  elapsed : Int32
  held : Bool
  resident_epoch : Int32
}

///|
pub extend NodeState with Eq::{not_equal, equal}

///|
pub extend NodeState with @debug.Debug::{to_repr}

///|
pub extend NodeState with Hash::{hash, hash_combine}

///|
pub extend NodeState with ToJson::{to_json}

///|
#derive(Eq, Debug, Hash)
pub(all) struct State {
  now : Int32
  a : NodeState
  b : NodeState
  owner : Node
  epoch : Int32
}

///|
pub extend State with Eq::{not_equal, equal}

///|
pub extend State with @debug.Debug::{to_repr}

///|
pub extend State with Hash::{hash, hash_combine}

///|
#derive(Eq, Debug, Hash)
pub(all) enum Event {
  AdvanceTime
  RenewNodeLease(Node)
  FenceExpiredNode(Node)
  TakeOver(Node)
  PublishCurrentOwner
}

///|
pub extend Event with Eq::{not_equal, equal}

///|
pub extend Event with @debug.Debug::{to_repr}

///|
pub extend Event with Hash::{hash, hash_combine}
