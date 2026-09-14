///|
/// Two passes reverse the implementation order; each has five timed batches.
fn measure(b : @bench.Bench, size : Int) -> Unit raise {
  for scenario in scenarios(size) {
    // Validate the exact measured input and optimized backend outside timing.
    for variant in scenario.variants {
      assert_eq((variant.run)(), scenario.expected)
    }
    for pass in 0..<2 {
      let variants = if pass == 0 {
        scenario.variants
      } else {
        scenario.variants.rev()
      }
      for variant in variants {
        b.bench(
          name="\{scenario.name}|n=\{size}|\{variant.name}|pass=\{pass}",
          () => b.keep((variant.run)()),
          count=5,
        )
      }
    }
  }
  // Stable envelope; retain the upstream numeric summary without table rounding.
  println("VERI_BENCH_JSON " + b.dump_summaries())
}

///|
test "collections n=256" (b : @bench.T) {
  measure(b, 256)
}

///|
test "collections n=2048" (b : @bench.T) {
  measure(b, 2048)
}
