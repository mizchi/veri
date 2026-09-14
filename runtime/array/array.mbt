///|
/// Read a cell when the index is in bounds, otherwise return None.
pub fn[T] get(
  array : FixedArray[T],
  index : Int,
) -> T? where {
  proof_ensure: result => {
    match result {
      Some(value) =>
        0 <= index &&
        index < array.length() &&
        same(value, @arrays.select(model(array), @integer.from_int(index)))
      None => index < 0 || array.length() <= index
    }
  },
} {
  if 0 <= index && index < array.length() {
    Some(array[index])
  } else {
    None
  }
}
