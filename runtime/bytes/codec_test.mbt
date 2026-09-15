///|
test "endian vectors, view offsets and truncated reads" {
  let le = @bytes.uint_to_le_bytes(0x12345678U)
  assert_eq(le, b"\x78\x56\x34\x12")
  assert_eq(@bytes.uint_to_be_bytes(0x12345678U), b"\x12\x34\x56\x78")
  assert_eq(
    @bytes.decode_uint_le(le[:], 0),
    Some({ value: 0x12345678U, next_offset: 4, }),
  )
  assert_eq(@bytes.decode_uint_le(le[:], 1), None)
  assert_eq(@bytes.decode_uint_le(le[:], -1), None)
  assert_eq(@bytes.decode_uint_le(le[:], 2147483647), None)
  let padded = b"\xaa\xbb\x78\x56\x34\x12\xcc"
  assert_eq(
    @bytes.decode_uint_le(padded[1:6], 1),
    Some({ value: 0x12345678U, next_offset: 5, }),
  )
  assert_eq(@bytes.decode_uint_le(padded[1:5], 1), None)
}
