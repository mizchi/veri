///|
test "native numeric names and byte readers compose with BytesView" {
  assert_eq(@bytes.byte_to_bytes(b'\x12'), b"\x12")
  assert_eq(@bytes.uint16_to_be_bytes(UInt16(0x1234)), b"\x12\x34")
  assert_eq(@bytes.uint_to_le_bytes(0x12345678U), b"\x78\x56\x34\x12")
  let wide = 0x123456789abcdef0UL
  assert_eq(@bytes.uint64_to_le_bytes(wide), wide.to_le_bytes())
  assert_eq(@bytes.uint64_to_be_bytes(wide), wide.to_be_bytes())
  let data = b"\xff\x12\x34\x56\x78\xee"[1:5]
  assert_eq(@bytes.read_byte(data, 0), Some(b'\x12'))
  assert_eq(@bytes.read_uint16_be(data, 1), Some(UInt16(0x3456)))
  assert_eq(@bytes.read_uint16_le(data, 1), Some(UInt16(0x5634)))
  assert_eq(@bytes.read_uint_be(data, 0), Some(0x12345678U))
  assert_eq(@bytes.read_uint_le(data, 0), Some(0x78563412U))
  assert_eq(@bytes.read_uint_be(data, 1), None)
  assert_eq(@bytes.read_byte(data, -1), None)
  assert_eq(@bytes.read_byte(data, 4), None)
  assert_eq(@bytes.read_uint64_be(data, 0), None)
  assert_eq(@bytes.read_uint64_le(wide.to_le_bytes()[:], 0), Some(wide))
  assert_eq(@bytes.read_uint64_be(wide.to_be_bytes()[:], 0), Some(wide))
  assert_eq(@bytes.decode_uint_be(data, 0).unwrap().next_offset, 4)
}
