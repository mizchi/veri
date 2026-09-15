///|
fn oracle(
  data : BytesView,
  offset : Int,
  width : Int,
  little : Bool,
) -> UInt64? {
  if offset < 0 || offset > data.length() || width > data.length() - offset {
    return None
  }
  let mut value = 0UL
  for i = 0; i < width; i = i + 1 {
    let index = if little { offset + width - 1 - i } else { offset + i }
    value = value * 256UL + data[index].to_uint64()
  }
  Some(value)
}

///|
fn expected_bytes(value : UInt64, width : Int, little : Bool) -> Bytes {
  let mut rest = value
  let result = Array::make(width, b'\x00')
  for i = 0; i < width; i = i + 1 {
    result[if little { i } else { width - 1 - i }] = (rest % 256UL).to_byte()
    rest = rest / 256UL
  }
  Bytes::from_array(result)
}

///|
test "quickcheck: u8 le codecs match positional model and reject truncation" {
  @quickcheck.check(
    (raw : UInt64) => {
      let value = raw.to_byte()
      let encoded = @bytes.byte_to_bytes(value)
      let expected = value.to_uint64()
      let truncated = Array::makei(1, i => i).all(size => {
        @bytes.decode_byte(encoded[:size], 0) is None
      })
      encoded == expected_bytes(expected, 1, true) &&
      @bytes.decode_byte(encoded[:], 0) == Some({ value, next_offset: 1, }) &&
      truncated
    },
    count=1000,
    max_shrinks=1000,
    seed=20260915,
  )
  @quickcheck.check(
    (input : (Bytes, Int)) => {
      let (data, raw_offset) = input
      let offset = raw_offset % (data.length() + 1)
      let actual = @bytes.decode_byte(data[:], offset)
      let expected = oracle(data[:], offset, 1, true)
      match (actual, expected) {
        (None, None) => true
        (Some(decoded), Some(expected)) =>
          decoded.value.to_uint64() == expected &&
          decoded.next_offset == offset + 1
        _ => false
      }
    },
    count=1000,
    max_size=32,
    max_shrinks=1000,
    seed=20260915,
  )
}

///|
test "quickcheck: u8 be codecs match positional model and reject truncation" {
  @quickcheck.check(
    (raw : UInt64) => {
      let value = raw.to_byte()
      let encoded = @bytes.byte_to_bytes(value)
      let expected = value.to_uint64()
      let truncated = Array::makei(1, i => i).all(size => {
        @bytes.decode_byte(encoded[:size], 0) is None
      })
      encoded == expected_bytes(expected, 1, false) &&
      @bytes.decode_byte(encoded[:], 0) == Some({ value, next_offset: 1, }) &&
      truncated
    },
    count=1000,
    max_shrinks=1000,
    seed=20260915,
  )
  @quickcheck.check(
    (input : (Bytes, Int)) => {
      let (data, raw_offset) = input
      let offset = raw_offset % (data.length() + 1)
      let actual = @bytes.decode_byte(data[:], offset)
      let expected = oracle(data[:], offset, 1, false)
      match (actual, expected) {
        (None, None) => true
        (Some(decoded), Some(expected)) =>
          decoded.value.to_uint64() == expected &&
          decoded.next_offset == offset + 1
        _ => false
      }
    },
    count=1000,
    max_size=32,
    max_shrinks=1000,
    seed=20260915,
  )
}

///|
test "quickcheck: u16 le codecs match positional model and reject truncation" {
  @quickcheck.check(
    (raw : UInt64) => {
      let value = raw.to_uint().to_uint16()
      let encoded = @bytes.uint16_to_le_bytes(value)
      let expected = value.to_int().to_uint64()
      let truncated = Array::makei(2, i => i).all(size => {
        @bytes.decode_uint16_le(encoded[:size], 0) is None
      })
      encoded == expected_bytes(expected, 2, true) &&
      @bytes.decode_uint16_le(encoded[:], 0) == Some({ value, next_offset: 2, }) &&
      truncated
    },
    count=1000,
    max_shrinks=1000,
    seed=20260915,
  )
  @quickcheck.check(
    (input : (Bytes, Int)) => {
      let (data, raw_offset) = input
      let offset = raw_offset % (data.length() + 1)
      let actual = @bytes.decode_uint16_le(data[:], offset)
      let expected = oracle(data[:], offset, 2, true)
      match (actual, expected) {
        (None, None) => true
        (Some(decoded), Some(expected)) =>
          decoded.value.to_int().to_uint64() == expected &&
          decoded.next_offset == offset + 2
        _ => false
      }
    },
    count=1000,
    max_size=32,
    max_shrinks=1000,
    seed=20260915,
  )
}

///|
test "quickcheck: u16 be codecs match positional model and reject truncation" {
  @quickcheck.check(
    (raw : UInt64) => {
      let value = raw.to_uint().to_uint16()
      let encoded = @bytes.uint16_to_be_bytes(value)
      let expected = value.to_int().to_uint64()
      let truncated = Array::makei(2, i => i).all(size => {
        @bytes.decode_uint16_be(encoded[:size], 0) is None
      })
      encoded == expected_bytes(expected, 2, false) &&
      @bytes.decode_uint16_be(encoded[:], 0) == Some({ value, next_offset: 2, }) &&
      truncated
    },
    count=1000,
    max_shrinks=1000,
    seed=20260915,
  )
  @quickcheck.check(
    (input : (Bytes, Int)) => {
      let (data, raw_offset) = input
      let offset = raw_offset % (data.length() + 1)
      let actual = @bytes.decode_uint16_be(data[:], offset)
      let expected = oracle(data[:], offset, 2, false)
      match (actual, expected) {
        (None, None) => true
        (Some(decoded), Some(expected)) =>
          decoded.value.to_int().to_uint64() == expected &&
          decoded.next_offset == offset + 2
        _ => false
      }
    },
    count=1000,
    max_size=32,
    max_shrinks=1000,
    seed=20260915,
  )
}

///|
test "quickcheck: u32 le codecs match positional model and reject truncation" {
  @quickcheck.check(
    (raw : UInt64) => {
      let value = raw.to_uint()
      let encoded = @bytes.uint_to_le_bytes(value)
      let expected = value.to_uint64()
      let truncated = Array::makei(4, i => i).all(size => {
        @bytes.decode_uint_le(encoded[:size], 0) is None
      })
      encoded == expected_bytes(expected, 4, true) &&
      @bytes.decode_uint_le(encoded[:], 0) == Some({ value, next_offset: 4, }) &&
      truncated
    },
    count=1000,
    max_shrinks=1000,
    seed=20260915,
  )
  @quickcheck.check(
    (input : (Bytes, Int)) => {
      let (data, raw_offset) = input
      let offset = raw_offset % (data.length() + 1)
      let actual = @bytes.decode_uint_le(data[:], offset)
      let expected = oracle(data[:], offset, 4, true)
      match (actual, expected) {
        (None, None) => true
        (Some(decoded), Some(expected)) =>
          decoded.value.to_uint64() == expected &&
          decoded.next_offset == offset + 4
        _ => false
      }
    },
    count=1000,
    max_size=32,
    max_shrinks=1000,
    seed=20260915,
  )
}

///|
test "quickcheck: u32 be codecs match positional model and reject truncation" {
  @quickcheck.check(
    (raw : UInt64) => {
      let value = raw.to_uint()
      let encoded = @bytes.uint_to_be_bytes(value)
      let expected = value.to_uint64()
      let truncated = Array::makei(4, i => i).all(size => {
        @bytes.decode_uint_be(encoded[:size], 0) is None
      })
      encoded == expected_bytes(expected, 4, false) &&
      @bytes.decode_uint_be(encoded[:], 0) == Some({ value, next_offset: 4, }) &&
      truncated
    },
    count=1000,
    max_shrinks=1000,
    seed=20260915,
  )
  @quickcheck.check(
    (input : (Bytes, Int)) => {
      let (data, raw_offset) = input
      let offset = raw_offset % (data.length() + 1)
      let actual = @bytes.decode_uint_be(data[:], offset)
      let expected = oracle(data[:], offset, 4, false)
      match (actual, expected) {
        (None, None) => true
        (Some(decoded), Some(expected)) =>
          decoded.value.to_uint64() == expected &&
          decoded.next_offset == offset + 4
        _ => false
      }
    },
    count=1000,
    max_size=32,
    max_shrinks=1000,
    seed=20260915,
  )
}

///|
test "quickcheck: u64 le codecs match positional model and reject truncation" {
  @quickcheck.check(
    (raw : UInt64) => {
      let value = raw
      let encoded = @bytes.uint64_to_le_bytes(value)
      let expected = value
      let truncated = Array::makei(8, i => i).all(size => {
        @bytes.decode_uint64_le(encoded[:size], 0) is None
      })
      encoded == expected_bytes(expected, 8, true) &&
      @bytes.decode_uint64_le(encoded[:], 0) == Some({ value, next_offset: 8, }) &&
      truncated
    },
    count=1000,
    max_shrinks=1000,
    seed=20260915,
  )
  @quickcheck.check(
    (input : (Bytes, Int)) => {
      let (data, raw_offset) = input
      let offset = raw_offset % (data.length() + 1)
      let actual = @bytes.decode_uint64_le(data[:], offset)
      let expected = oracle(data[:], offset, 8, true)
      match (actual, expected) {
        (None, None) => true
        (Some(decoded), Some(expected)) =>
          decoded.value == expected && decoded.next_offset == offset + 8
        _ => false
      }
    },
    count=1000,
    max_size=32,
    max_shrinks=1000,
    seed=20260915,
  )
}

///|
test "quickcheck: u64 be codecs match positional model and reject truncation" {
  @quickcheck.check(
    (raw : UInt64) => {
      let value = raw
      let encoded = @bytes.uint64_to_be_bytes(value)
      let expected = value
      let truncated = Array::makei(8, i => i).all(size => {
        @bytes.decode_uint64_be(encoded[:size], 0) is None
      })
      encoded == expected_bytes(expected, 8, false) &&
      @bytes.decode_uint64_be(encoded[:], 0) == Some({ value, next_offset: 8, }) &&
      truncated
    },
    count=1000,
    max_shrinks=1000,
    seed=20260915,
  )
  @quickcheck.check(
    (input : (Bytes, Int)) => {
      let (data, raw_offset) = input
      let offset = raw_offset % (data.length() + 1)
      let actual = @bytes.decode_uint64_be(data[:], offset)
      let expected = oracle(data[:], offset, 8, false)
      match (actual, expected) {
        (None, None) => true
        (Some(decoded), Some(expected)) =>
          decoded.value == expected && decoded.next_offset == offset + 8
        _ => false
      }
    },
    count=1000,
    max_size=32,
    max_shrinks=1000,
    seed=20260915,
  )
}

///|
test "byte inputs shrink in length, byte values and offsets" {
  let input : (Bytes, Int) = (b"\xff\x80\x10", 17)
  assert_true(@shrink.Shrink::shrink(input).any(x => x.0.length() == 0))
  assert_true(@shrink.Shrink::shrink(input).any(x => x.1 == 0))
  assert_true(
    @shrink.Shrink::shrink(input.0).any(x => x.length() == 3 && x[0] == b'\x00'),
  )
}

///|
test "codec maximum values and every byte width" {
  for value in [0UL, 1UL, 0x8000000000000000UL, 0xffffffffffffffffUL] {
    assert_eq(
      @bytes.decode_uint64_le(@bytes.uint64_to_le_bytes(value)[:], 0).unwrap().value,
      value,
    )
    assert_eq(
      @bytes.decode_uint64_be(@bytes.uint64_to_be_bytes(value)[:], 0).unwrap().value,
      value,
    )
  }
  assert_eq(@bytes.read_end(2147483647, 2147483647, 1), None)
  assert_eq(@bytes.read_end(2147483647, 2147483646, 1), Some(2147483647))
  assert_eq(@bytes.read_end(-1, 0, 0), None)
  assert_eq(@bytes.read_end(0, 0, 0), Some(0))
}
