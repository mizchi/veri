///|
/// Encode a single byte; byte order does not apply to a one-byte value.
pub fn byte_to_bytes(value : Byte) -> Bytes {
  Bytes::from_array([value])
}

///|
/// Reject negative, overflowing or truncated offsets; positions are view-relative.
/// read_end is proved. Native byte loads and casts are differential-tested.
pub fn decode_byte(data : BytesView, offset : Int) -> Decoded[Byte]? {
  match read_end(data.length(), offset, 1) {
    None => None
    Some(next_offset) => Some({ value: data[offset], next_offset, })
  }
}

///|
/// Encode all bits in LE order. Native operations are differential-tested.
pub fn uint16_to_le_bytes(value : UInt16) -> Bytes {
  Bytes::from_array([
    (value.to_int() >> 0).to_byte(),
    (value.to_int() >> 8).to_byte(),
  ])
}

///|
/// Reject negative, overflowing or truncated offsets; positions are view-relative.
/// read_end is proved. Native byte loads and casts are differential-tested.
pub fn decode_uint16_le(data : BytesView, offset : Int) -> Decoded[UInt16]? {
  match read_end(data.length(), offset, 2) {
    None => None
    Some(next_offset) =>
      Some({ value: data.unsafe_read_uint16_le(offset), next_offset, })
  }
}

///|
/// Encode all bits in BE order. Native operations are differential-tested.
pub fn uint16_to_be_bytes(value : UInt16) -> Bytes {
  Bytes::from_array([
    (value.to_int() >> 8).to_byte(),
    (value.to_int() >> 0).to_byte(),
  ])
}

///|
/// Reject negative, overflowing or truncated offsets; positions are view-relative.
/// read_end is proved. Native byte loads and casts are differential-tested.
pub fn decode_uint16_be(data : BytesView, offset : Int) -> Decoded[UInt16]? {
  match read_end(data.length(), offset, 2) {
    None => None
    Some(next_offset) =>
      Some({ value: data.unsafe_read_uint16_be(offset), next_offset, })
  }
}

///|
/// Encode all bits in LE order. Native operations are differential-tested.
pub fn uint_to_le_bytes(value : UInt) -> Bytes {
  Bytes::from_array([
    (value >> 0).to_byte(),
    (value >> 8).to_byte(),
    (value >> 16).to_byte(),
    (value >> 24).to_byte(),
  ])
}

///|
/// Reject negative, overflowing or truncated offsets; positions are view-relative.
/// read_end is proved. Native byte loads and casts are differential-tested.
pub fn decode_uint_le(data : BytesView, offset : Int) -> Decoded[UInt]? {
  match read_end(data.length(), offset, 4) {
    None => None
    Some(next_offset) =>
      Some({ value: data.unsafe_read_uint32_le(offset), next_offset, })
  }
}

///|
/// Encode all bits in BE order. Native operations are differential-tested.
pub fn uint_to_be_bytes(value : UInt) -> Bytes {
  Bytes::from_array([
    (value >> 24).to_byte(),
    (value >> 16).to_byte(),
    (value >> 8).to_byte(),
    (value >> 0).to_byte(),
  ])
}

///|
/// Reject negative, overflowing or truncated offsets; positions are view-relative.
/// read_end is proved. Native byte loads and casts are differential-tested.
pub fn decode_uint_be(data : BytesView, offset : Int) -> Decoded[UInt]? {
  match read_end(data.length(), offset, 4) {
    None => None
    Some(next_offset) =>
      Some({ value: data.unsafe_read_uint32_be(offset), next_offset, })
  }
}

///|
/// Encode all bits in LE order. Native operations are differential-tested.
pub fn uint64_to_le_bytes(value : UInt64) -> Bytes {
  value.to_le_bytes()
}

///|
/// Reject negative, overflowing or truncated offsets; positions are view-relative.
/// read_end is proved. Native byte loads and casts are differential-tested.
pub fn decode_uint64_le(data : BytesView, offset : Int) -> Decoded[UInt64]? {
  match read_end(data.length(), offset, 8) {
    None => None
    Some(next_offset) =>
      Some({ value: data.unsafe_read_uint64_le(offset), next_offset, })
  }
}

///|
/// Encode all bits in BE order. Native operations are differential-tested.
pub fn uint64_to_be_bytes(value : UInt64) -> Bytes {
  value.to_be_bytes()
}

///|
/// Reject negative, overflowing or truncated offsets; positions are view-relative.
/// read_end is proved. Native byte loads and casts are differential-tested.
pub fn decode_uint64_be(data : BytesView, offset : Int) -> Decoded[UInt64]? {
  match read_end(data.length(), offset, 8) {
    None => None
    Some(next_offset) =>
      Some({ value: data.unsafe_read_uint64_be(offset), next_offset, })
  }
}
