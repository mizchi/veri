///|
/// A successful read advances by exactly the selected width, relative to the view.
pub(all) struct Decoded[T] {
  value : T
  next_offset : Int32
} derive(Debug, Eq)

///|
pub extend Decoded with @debug.Debug::{to_repr}

///|
pub extend Decoded with Eq::{not_equal, equal}

///|
/// Overflow-free bounds and consumed-length check. Width may be zero.
pub fn read_end(
  length : Int32,
  offset : Int32,
  width : Int32,
) -> Int32? where {
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
