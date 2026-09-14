///|
test "benchmark workloads produce the reference output on every invocation" {
  for size in [0, 1, 16, 64] {
    for scenario in scenarios(size) {
      for variant in scenario.variants {
        assert_eq((variant.run)(), scenario.expected)
        // Mutable baselines must create fresh state on every invocation.
        assert_eq((variant.run)(), scenario.expected)
      }
    }
  }
}

///|
test "benchmark permutations contain every key once and are reproducible" {
  for size in [0, 1, 16, 256, 2048] {
    let values = shuffled(size)
    assert_eq(values, shuffled(size))
    values.sort()
    assert_eq(values, Array::makei(size, i => i))
  }
}
