# Collection benchmarks

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
