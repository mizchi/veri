///|
test "codepoint positions differ from UTF-16 offsets" {
  let text = @text.from_string("A😀é").unwrap()
  assert_eq("A😀é".length(), 4)
  assert_eq(text.length(), 3)
  assert_eq(text.char_at(1).to_string(), "😀")
  assert_eq(text.substring(1, 2).to_string(), "😀é")
  assert_eq(text.substring(1, 2147483647).to_string(), "😀é")
  assert_eq(text.substring(-1, 2).to_string(), "")
  assert_eq(text.substring(3, 1).to_string(), "")
  assert_eq(text.substring(0, -1).to_string(), "")
  assert_eq(text.char_at(-2147483648).to_string(), "")
  assert_eq(text.char_at(2147483647).to_string(), "")
}

///|
test "reject unpaired UTF-16 surrogates" {
  let pair = "😀"
  assert_true(@text.from_string(pair) is Some(_))
  // Construct malformed UTF-16 deliberately; ordinary String::sub rejects it.
  assert_true(@text.from_string(pair.unsafe_substring(start=0, end=1)) is None)
  assert_true(@text.from_string(pair.unsafe_substring(start=1, end=2)) is None)
  assert_true(
    @text.from_string(pair.unsafe_substring(start=0, end=1) + "x") is None,
  )
  assert_true(@text.from_string("") is Some(_))
}

///|
test "reject Unicode planes outside the SMT alphabet" {
  assert_true(@text.from_string("\u{2ffff}") is Some(_))
  assert_true(@text.from_string("\u{30000}") is None)
  assert_true(@text.from_string("\u{10ffff}") is None)
}
