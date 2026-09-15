///|
/// Read a value at a view-relative offset. Return None for an invalid or truncated
/// range. Use decode_byte when the next offset is also needed.
pub fn read_byte(data : BytesView, offset : Int) -> Byte? {
  decode_byte(data, offset).map(decoded => decoded.value)
}

///|
/// Read a value at a view-relative offset. Return None for an invalid or truncated
/// range. Use decode_uint16_le when the next offset is also needed.
pub fn read_uint16_le(data : BytesView, offset : Int) -> UInt16? {
  decode_uint16_le(data, offset).map(decoded => decoded.value)
}

///|
/// Read a value at a view-relative offset. Return None for an invalid or truncated
/// range. Use decode_uint16_be when the next offset is also needed.
pub fn read_uint16_be(data : BytesView, offset : Int) -> UInt16? {
  decode_uint16_be(data, offset).map(decoded => decoded.value)
}

///|
/// Read a value at a view-relative offset. Return None for an invalid or truncated
/// range. Use decode_uint_le when the next offset is also needed.
pub fn read_uint_le(data : BytesView, offset : Int) -> UInt? {
  decode_uint_le(data, offset).map(decoded => decoded.value)
}

///|
/// Read a value at a view-relative offset. Return None for an invalid or truncated
/// range. Use decode_uint_be when the next offset is also needed.
pub fn read_uint_be(data : BytesView, offset : Int) -> UInt? {
  decode_uint_be(data, offset).map(decoded => decoded.value)
}

///|
/// Read a value at a view-relative offset. Return None for an invalid or truncated
/// range. Use decode_uint64_le when the next offset is also needed.
pub fn read_uint64_le(data : BytesView, offset : Int) -> UInt64? {
  decode_uint64_le(data, offset).map(decoded => decoded.value)
}

///|
/// Read a value at a view-relative offset. Return None for an invalid or truncated
/// range. Use decode_uint64_be when the next offset is also needed.
pub fn read_uint64_be(data : BytesView, offset : Int) -> UInt64? {
  decode_uint64_be(data, offset).map(decoded => decoded.value)
}
