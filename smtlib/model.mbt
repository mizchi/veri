///|
/// An assignment of values to declared constants: a solver model, or the
/// runtime inputs of a concrete evaluation.
#derive(Debug)
pub struct Model {
  priv values : Map[String, Value]
}

///|
pub extend Model with @debug.Debug::{to_repr}

///|
pub fn Model::new() -> Model {
  { values: Map([]), }
}

///|
pub fn Model::set(self : Model, name : String, value : Value) -> Unit {
  self.values.set(name, value)
}

///|
pub fn Model::get(self : Model, name : String) -> Value? {
  self.values.get(name)
}

///|
pub fn Model::length(self : Model) -> Int32 {
  self.values.length()
}

///|
/// Assigned names in insertion order.
pub fn Model::names(self : Model) -> Array[String] {
  self.values.keys().to_array()
}

///|
/// Assign a runtime value to a typed constant.
pub fn[T : Encode] Model::bind(
  self : Model,
  constant : Typed[T],
  value : T,
) -> Unit raise SmtError {
  self.values.set(constant.name, T::to_value(value))
}

///|
/// Read a typed constant back as a runtime value.
pub fn[T] Model::read(self : Model, constant : Typed[T]) -> T? {
  match self.values.get(constant.name) {
    Some(value) => (constant.decode)(value)
    None => None
  }
}
