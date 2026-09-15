///|
test "composed reads are relative to the view and leave input unchanged on failure" {
  let data : Bytes = b"\xff\x01\x00\x02\xee"
  let cursor = @cursor.Cursor::new(data[1:4])
  let parser = @cursor.byte().zip(@cursor.uint16_be())
  let ((tag, value), rest) = cursor.read(parser).unwrap()
  assert_eq(tag, b'\x01')
  assert_eq(value, 2U.to_uint16())
  assert_eq(rest.position(), 3)
  assert_eq(rest.remaining(), 0)
  assert_eq(cursor.position(), 0)
  assert_true(rest.read(@cursor.byte()) is None)
  assert_true(cursor.read(parser.zip(@cursor.byte())) is None)
  assert_eq(cursor.position(), 0)
  assert_true(cursor.read(@cursor.take(-1)) is None)
  assert_true(cursor.read(@cursor.take(2147483647)) is None)
}

///|
test "length prefix rejects truncation and unrepresentable length" {
  let data : Bytes = b"\x00\x00\x00\x02hi!"
  let start = @cursor.Cursor::new(data[:])
  let (body, rest) = start.read(@cursor.length_prefixed_uint_be()).unwrap()
  assert_eq(body.to_owned(), b"hi")
  assert_eq(rest.position(), 6)
  assert_true(
    @cursor.Cursor::new(data[:5]).read(@cursor.length_prefixed_uint_be())
    is None,
  )
  assert_true(
    @cursor.Cursor::new(b"\xff\xff\xff\xff"[:]).read(
      @cursor.length_prefixed_uint_be(),
    )
    is None,
  )
}

///|
test "quickcheck: parser composition consumes exact lengths with shrinking" {
  @quickcheck.check(
    (input : (Byte, UInt, Bytes)) => {
      let (tag, value, tail) = input
      let encoded = @codec.byte_to_bytes(tag) +
        @codec.uint_to_be_bytes(value) +
        tail
      let original = @cursor.Cursor::new(encoded[:])
      let parser = @cursor.byte()
        .zip(@cursor.uint_be())
        .zip(@cursor.take(tail.length()))
      let (((a, b), body), rest) = original.read(parser).unwrap()
      if a != tag ||
        b != value ||
        body.to_owned() != tail ||
        rest.remaining() != 0 ||
        original.position() != 0 {
        return false
      }
      for size = 0; size < encoded.length(); size = size + 1 {
        if @cursor.Cursor::new(encoded[:size]).read(parser) is Some(_) {
          return false
        }
      }
      let frame = @codec.uint_to_be_bytes(tail.length().reinterpret_as_uint()) +
        tail
      match
        @cursor.Cursor::new(frame[:]).read(@cursor.length_prefixed_uint_be()) {
        Some((decoded, rest)) =>
          decoded.to_owned() == tail && rest.remaining() == 0
        None => false
      }
    },
    count=500,
    max_size=32,
    max_shrinks=1000,
    seed=20260924,
  )
}

///|
test "fallback restarts at the original position and mapping preserves offsets" {
  let data : Bytes = b"\x03abc"
  let start = @cursor.Cursor::new(data[:])
  let parser = @cursor.take(5)
    .map(_ => -1)
    .or_else(@cursor.byte().map(x => x.to_int()))
  let (value, rest) = start.read(parser).unwrap()
  assert_eq(value, 3)
  assert_eq(rest.position(), 1)
  let dependent = @cursor.byte().and_then(size => @cursor.take(size.to_int()))
  let (body, rest) = start.read(dependent).unwrap()
  assert_eq(body.to_owned(), b"abc")
  assert_eq(rest.remaining(), 0)
  let (empty, same) = start.read(@cursor.take(0)).unwrap()
  assert_eq(empty.length(), 0)
  assert_eq(same.position(), start.position())
}

///|
test "quickcheck: arbitrary take lengths compose or fail without consuming input" {
  @quickcheck.check(
    (input : (Bytes, Int, Int)) => {
      let (data, raw_first, raw_second) = input
      let first = raw_first % (data.length() + 2)
      let second = raw_second % (data.length() + 2)
      let start = @cursor.Cursor::new(data[:])
      let parsed = start.read(@cursor.take(first).zip(@cursor.take(second)))
      let valid = first >= 0 &&
        second >= 0 &&
        first <= data.length() &&
        second <= data.length() - first
      match parsed {
        None => !valid && start.position() == 0
        Some(((a, b), rest)) =>
          valid &&
          a.length() == first &&
          b.length() == second &&
          a.to_owned() + b.to_owned() == data[:first + second].to_owned() &&
          rest.position() == first + second &&
          start.position() == 0
      }
    },
    count=500,
    max_size=32,
    max_shrinks=1000,
    seed=20260925,
  )
}
