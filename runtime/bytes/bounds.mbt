///|
/// A successful read advances by exactly the selected width, relative to the view.
pub(all) struct Decoded[T] {
  value : T
  next_offset : Int
} derive(Debug, Eq)

///|
/// Overflow-free bounds and consumed-length check. Width may be zero.
pub fn read_end(
  length : Int,
  offset : Int,
  width : Int,
) -> Int? where {
  proof_ensure: result => {
    match result {
      None =>
        !(0 <= offset &&
        offset <= length &&
        0 <= width &&
        width <= length - offset)
      Some(stop) =>
        0 <= offset &&
        0 <= width &&
        offset <= stop &&
        stop <= length &&
        stop - offset == width
    }
  },
} {
  if 0 <= offset && offset <= length && 0 <= width && width <= length - offset {
    Some(offset + width)
  } else {
    None
  }
}
