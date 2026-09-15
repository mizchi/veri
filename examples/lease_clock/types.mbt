///|
pub(all) enum Node {
  A
  B
} derive(Eq, Debug)

///|
pub(all) enum Variant {
  Vulnerable
  BoundedSkew
} derive(Eq, Debug)

///|
pub(all) struct NodeState {
  expires : Int
  elapsed : Int
  held : Bool
  resident_epoch : Int
} derive(Eq, Debug, ToJson)

///|
pub(all) struct State {
  now : Int
  a : NodeState
  b : NodeState
  owner : Node
  epoch : Int
} derive(Eq, Debug)

///|
pub(all) enum Event {
  AdvanceTime
  RenewNodeLease(Node)
  FenceExpiredNode(Node)
  TakeOver(Node)
  PublishCurrentOwner
} derive(Eq, Debug)
