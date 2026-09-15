///|
using @list {type List}

///|
/// Allocation size: neither the product nor the header addition can wrap.
pub fn allocation_size(
  count : Int,
  stride : Int,
  header : Int,
) -> Int? where {
  proof_require: 0 <= count && count <= 2147483647,
  proof_require: 0 <= stride && stride <= 2147483647,
  proof_require: 0 <= header && header <= 2147483647,
  proof_ensure: result => {
    match result {
      None => !@int32.in_range(allocation_value(count, stride, header))
      Some(value) =>
        @int32.in_range(allocation_value(count, stride, header)) &&
        @integer.eq(
          @integer.from_int(value),
          allocation_value(count, stride, header),
        )
    }
  },
} {
  match @int32.checked_mul(count, stride) {
    None => {
      proof_assert @integer.le(
        @integer.zero(),
        @integer.mul(@integer.from_int(count), @integer.from_int(stride)),
      )
      proof_assert @integer.lt(
        @integer.from_int(2147483647),
        @integer.mul(@integer.from_int(count), @integer.from_int(stride)),
      )
      None
    }
    Some(payload) => @int32.checked_add(payload, header)
  }
}

///|
/// Parse a network-order record header from a view; offset is carried explicitly.
pub fn read_header(data : BytesView, offset : Int) -> (UInt16, UInt, Int)? {
  match @bytes.decode_uint16_be(data, offset) {
    None => None
    Some(tag) =>
      match @bytes.decode_uint_be(data, tag.next_offset) {
        None => None
        Some(length) => Some((tag.value, length.value, length.next_offset))
      }
  }
}

///|
/// A checked bridge from decoded unsigned lengths to MoonBit collection indices.
pub fn length_as_int(length : UInt) -> Int? {
  @conversion.checked_uint_to_int(length)
}

///|
/// Dijkstra combines the existing priority queue and FIFO queue internally.
/// The caller can independently validate the returned distances and paths.
pub fn route(
  edges : ArrayView[@graph.Edge],
  vertex_count : Int,
  source : Int,
  target : Int,
) -> Array[Int]? raise @graph.GraphError {
  let graph = @graph.Graph::from_array(edges, vertex_count~)
  graph.dijkstra(source).path_to(target)
}
