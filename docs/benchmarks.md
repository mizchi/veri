# Benchmarks

[日本語](benchmarks.ja.md) | [README](../README.md)

## Collection benchmarks

`benchmarks/collections` uses [MoonBit's benchmark API](https://docs.moonbitlang.com/en/latest/language/benchmarks.html)
through `moon bench --release --no-parallelize`. It measures 14 workloads at
256 and 2,048 elements, producing 34 comparisons per backend. Two direct tree
`to_array()` workloads supplement the unchanged `inorder().to_array()` workloads. Each implementation
runs in two opposite orders with five calibrated batches per pass. Results are
kept with `Bench.keep`, and exact output equality is checked before timing on
the same optimized backend. Empty inputs and repeated calls are also tested.

| Workload | Core comparison | Timed work |
| --- | --- | --- |
| List | `core/list` | Reverse/append followed by array conversion; length |
| Stack | `core/list`, built-in `Array` | Push all elements, then drain into a fresh array |
| Queue | `core/queue` | Push and drain; repeated peek on a prebuilt queue |
| Minimum priority queue | `core/immut/priority_queue`, `core/priority_queue`, both using `Reverse[Int]` | Push and drain, including duplicates, shuffled and ascending inputs |
| BST | `core/immut/sorted_set` | Insert, then query every key and equally many missing keys, with shuffled and ascending insertion |
| Binary-tree traversal | `core/immut/sorted_set` | Materialize the same contents from balanced and left-skewed trees, measuring linked-list intermediates and direct arrays separately |

The generic binary tree has no direct core counterpart here; its comparator
performs ordered enumeration, not arbitrary-shape tree manipulation. Mutable
baselines are used with one current state and no retained snapshots; no copying
is charged to simulate persistence. Input generation and read-only fixture
construction are outside timing; build/drain and build/find workloads include
their own fresh construction and output work. Repeated peek uses the same queue
without popping; the updated queue normalizes on mutation and avoids repeated reversal. A compiler may
hoist repeated reads; these are timings of the optimized workload, not isolated
function-call latency.

`just bench native` (or `js`, `wasm`, `wasm-gc`) saves raw output, JSON summaries,
and a Markdown comparison under `_build/benchmarks/collections-<target>.*`.
The report records toolchain, CPU, OS, repository revision, and a fingerprint of
the installed core sources, plus separate SHA-256 hashes of runtime and benchmark sources. Times are the mean of the two batch medians in
microseconds; the ratio is **veri/core**, so values above 1 mean slower. The
paired ratio range describes order variation and is not a confidence interval.
Missing results, invalid timings, and failed benchmark processes fail reporting.

`just bench-check native 1.0` performs a fresh measurement and exits nonzero if
any comparison exceeds the supplied limit in either order. Results straddling
the limit are inconclusive and also fail this check. Benchmarks are separate
from `just verify`, since timing depends on hardware and system load.

The [latest tuning measurements](../benchmarks/collections/TUNING.md) show that the
current implementations **do not meet a universal no-slowdown target**. These
comparisons include representation, allocation, and algorithm differences; they
do not isolate proof-contract overhead. Proof-only `seq/list/bag/fmap/bintree`
bindings have no runtime operations to benchmark. Rerun on your deployment
backend and workload before relying on a performance comparison.
The [2026-09-14 measurements](../benchmarks/collections/RESULTS.md) remain available
as a historical snapshot of the previous skew-heap implementation.

## SMT-LIB benchmarks

`benchmarks/smtlib` measures the SMT-LIB paths with the same benchmark API:
the model-check encoder and witness decoder, and `smtlib` term building,
printing, evaluation and answer decoding. `just bench-smtlib native` (or `js`,
`wasm`, `wasm-gc`) saves a log, JSON and Markdown report under
`_build/benchmarks/smtlib-<target>.*`.

Where a previous implementation exists it stays in the benchmark package as
the **reference**: the 0.2.1 encoder and decoder, nested string concatenation
for term building, and the expanded tree for a shared term. Reference and
tuned outputs are compared for exact equality on the measured backend before
timing, so the reference is also the oracle for the tuned code. Each variant
runs in two passes with the order reversed, five calibrated batches per pass,
and every resulting string is materialized so that a JavaScript rope is not
compared with a flat string.

The [recorded measurements](../benchmarks/smtlib/RESULTS.md) show that the
tuning **does not make every workload faster on every backend**:

| Workload | native | js | wasm | wasm-gc |
| --- | ---: | ---: | ---: | ---: |
| Encode a fair response query, depth 64 | 4.17× | 1.88× | 6.87× | 3.12× |
| Encode initial definitions, 2,048 states | 3.22× | 1.03× | 3.04× | 2.08× |
| Incremental safety conditions, depth 64 | 1.96× | 1.07× | 2.07× | 2.40× |
| Decode a witness, depth 1,024 | 5.08× | 2.43× | 8.51× | 5.39× |
| Build and print 6,146 unshared terms | 10.15× | 0.10× | 5.29× | 57.41× |
| Print a term shared across 10 rounds | 242× | 157× | 117× | 1,768× |

Values are reference time divided by tuned time, so values below 1 are
slowdowns. On JavaScript, string concatenation of an unshared term is about
ten times faster than building it in a `Context`: engines keep concatenation
results as ropes. Choose `smtlib` there for sharing, sort checking,
evaluation and decoding rather than for raw printing speed. Timings come from
one shared cloud VM; rerun on your backend and workload before relying on them.
