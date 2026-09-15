///|
pub fn byte() -> Parser[Byte] {
  { parse: @codec.decode_byte, }
}

///|
pub fn uint16_le() -> Parser[UInt16] {
  { parse: @codec.decode_uint16_le, }
}

///|
pub fn uint16_be() -> Parser[UInt16] {
  { parse: @codec.decode_uint16_be, }
}

///|
pub fn uint_le() -> Parser[UInt] {
  { parse: @codec.decode_uint_le, }
}

///|
pub fn uint_be() -> Parser[UInt] {
  { parse: @codec.decode_uint_be, }
}

///|
pub fn uint64_le() -> Parser[UInt64] {
  { parse: @codec.decode_uint64_le, }
}

///|
pub fn uint64_be() -> Parser[UInt64] {
  { parse: @codec.decode_uint64_be, }
}
