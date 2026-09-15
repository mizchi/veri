///|
/// The property is evaluated on a replay of the actual model function.
pub(all) enum Property {
  Safety(String)
  Reachability(String)
  Response(String, String)
  Deadlock(String)
} derive(Eq, Debug)

///|
pub(all) struct Witness {
  states : Array[Int]
  actions : Array[Int]
  loop_start : Int?
} derive(@json.FromJson, ToJson, Eq, Debug)

///|
pub(all) struct Scope {
  complete : Bool
  max_depth : Int
  depths : Array[Int]
  frontier : Array[Int]
} derive(ToJson, @json.FromJson)

///|
/// Shared finite-model wire format. Snapshots are for inspection, not replay.
/// None means the adapter enumerates the complete state domain or closure.
pub(all) struct Model[Snapshot] {
  initial : Int
  actions : Array[String]
  states : Array[Snapshot]
  transitions : Array[Array[Int]]
  predicates : Map[String, Array[Bool]]
  justice : Array[Int]
  exploration : Scope?
} derive(ToJson, @json.FromJson)

///|
/// An adapter keeps executable states and callbacks separate from JSON snapshots.
/// Supply immutable states, stable event order, deterministic step and predicates.
/// Model metadata must describe this same state domain and transition function.
pub(all) struct Client[S, E, Snapshot] {
  initial : S
  states : Array[S]
  events : Array[E]
  step : (S, E) -> S?
  holds : (S, String) -> Bool?
  model : Model[Snapshot]
}
