///|
/// The property is evaluated on a replay of the actual model function.
pub(all) enum Property {
  Safety(String)
  Reachability(String)
  Response(String, String)
  Deadlock(String)
} derive(Eq, Debug)

///|
pub extend Property with Eq::{not_equal, equal}

///|
pub extend Property with @debug.Debug::{to_repr}

///|
pub(all) struct Witness {
  states : Array[Int32]
  actions : Array[Int32]
  loop_start : Int32?
} derive(@json.FromJson, ToJson, Eq, Debug)

///|
pub extend Witness with @json.FromJson::{from_json}

///|
pub extend Witness with ToJson::{to_json}

///|
pub extend Witness with Eq::{not_equal, equal}

///|
pub extend Witness with @debug.Debug::{to_repr}

///|
pub(all) struct Scope {
  complete : Bool
  max_depth : Int32
  depths : Array[Int32]
  frontier : Array[Int32]
} derive(ToJson, @json.FromJson)

///|
pub extend Scope with ToJson::{to_json}

///|
pub extend Scope with @json.FromJson::{from_json}

///|
/// Shared finite-model wire format. Snapshots are for inspection, not replay.
/// None means the adapter enumerates the complete state domain or closure.
pub(all) struct Model[Snapshot] {
  initial : Int32
  actions : Array[String]
  states : Array[Snapshot]
  transitions : Array[Array[Int32]]
  predicates : Map[String, Array[Bool]]
  justice : Array[Int32]
  exploration : Scope?
} derive(ToJson, @json.FromJson)

///|
pub extend Model with ToJson::{to_json}

///|
pub extend Model with @json.FromJson::{from_json}

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
