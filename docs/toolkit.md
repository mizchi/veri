# Runtime APIs and graph checking

[日本語](toolkit.ja.md) | [README](../README.md)

## Maps, sets, search, dependencies, and parsers

`runtime/map.Map` and `runtime/set.Set` **re-export the core types themselves**.
They interoperate directly with the standard `Map` / `Set`; mutation and iteration
use the same implementation. Optional `matches_entries` / `matches_elements`
check exact contents in any order and reject duplicate keys/elements. Normal
operations incur no checker or model-copying cost. `fmap.updated` / `removed` and
`fset.added` / `removed` specify logical transitions, with proved lookup,
membership, frame, and cardinality laws. Correspondence with core bodies is
checked against independent array models, including operation traces with
constant-hash keys. Keys corresponding to logical equality require equivalence
laws for `Eq` and equal hashes for equal keys.

`runtime/search` provides `lower_bound` (first `>=`) and `upper_bound` (first `>`)
on `FixedArray[Int]`. Their implementation bodies prove the partition boundaries
under an ascending-order precondition, with both integer preludes. Searches take
O(log n) time without copying. `is_sorted` is a proved O(n) checker for that exact
precondition. Callers must establish sortedness or check it first.
`check_sort(before, after)` checks ascending order and every multiplicity at
runtime. Save a pre-sort copy when checking core's in-place sort. This Map-based
result checker is differential-tested, not formally proved.

`Graph::topological_sort()` returns `Ordered(order)` or `Cyclic(cycle)`, both
containing `FixedArray[Int]`. The order is a permutation of every vertex; a simple
cycle repeats its first vertex at the end (`[v, v]` for a self-loop).
Use `graph.check_topology(witness)` to validate either verdict, or call
`check_topological_order(order)` / `check_cycle(cycle)` on the actual arrays.
**The complete checker bodies and their soundness are proved under both normal
and machine integers.** Accepting an order proves its permutation, every edge's
orientation, and acyclicity. Accepting a cycle proves simplicity, actual consecutive
edges, and a nonempty closed path. Clients can use `topological_order`, `simple_cycle`,
`acyclic`, `cyclic`, and `valid_topology` in their contracts.

`runtime/graph/topology` checks the actual edge and witness arrays. The order
checker allocates a rank table; the cycle checker uses a visited table and CSR
ranges. Both take O(V+E) time and O(V) space for CSR graphs. Checking the ranges
and actual endpoints prevents malformed offsets from fabricating edges or
causing invalid reads. Weights are irrelevant. The DFS producer and construction
of its returned arrays remain differential-tested; the checker proof assumes
neither is correct. Tests cover transitive closure, arbitrary certificates,
20,000-vertex chains/cycles, and shrinking QuickCheck properties.

To migrate the unpublished API, replace `check_topological_order(order[:])` with
`check_topological_order(order)`. `check_topological_order_view` / `check_cycle_view`
accept `ArrayView[Int]` by copying it before checking. Offset-view properties test
these adapters. ArrayView reads are unsupported in the current proof frontend;
verified clients use the FixedArray APIs.

`runtime/union_find.UnionFind::new(n)` manages elements in `0..<n`, with `find`,
`same`, `union`, `component_size`, `component_count`, `copy`, and `to_array`.
Invalid sizes/elements raise `UnionFindError`. `union` returns true exactly when
two components were joined; representative identity is unspecified. Union by
size and path compression are differential-tested against flat partition labels.
The logical `union_find` package proves that exactly the selected classes merge
and that the resulting relation is an equivalence. The mutable parent-array and
path-compression bodies are not proved.


`examples/toolkit/kruskal.mbt` also combines core sorting and Union-Find to build
a minimum spanning forest of an undirected graph. Its optimality is not formally proved.

`runtime/bytes/cursor` provides an immutable `Cursor` and `Parser[T]`.
`Cursor::read(parser)` returns `Some((value, next_cursor))` or `None`.
Compose `byte`, LE/BE integer readers, and `take` using `zip`, `map`, `and_then`,
and `or_else`. `length_prefixed_uint_be()` reads a 32-bit BE length and a payload
`BytesView`, rejecting truncation and lengths beyond Int range. Reading does not
copy bytes. The original cursor stays unchanged on success and failure; fallback
restarts at the original position. Callback side effects are not rolled back.
The `read_end` body and `encoding.read_composition` consumed-length laws are
proved; native codecs and parser composition are checked with shrinking properties.

```sh
just verify-extensions # proofs, false controls, four backends in debug/release
just graph-capabilities # consume graph contracts and probe ArrayView adapter lowering
```

**The complete BFS/Dijkstra certificate checkers are soundness-proved** under both
normal and machine integers. `runtime/graph/checker.check_certificate` validates
arbitrary inputs: accepted distances are attained by real paths, bound every path
from below, and label exactly the reachable vertices. It checks predecessor chains,
all edge inequalities, array sizes, endpoints and nonnegative weights.
`relaxation` avoids constructing an overflowing sum, including on overflowing detours.
Public `Graph::check_bfs` / `check_dijkstra` pass their actual stored arrays directly
to this proved implementation. Clients can use `certified`, `shortest_at`, and the
contracted `SearchResult::distance` accessor. Core Map/Set and the copying step
in the ArrayView convenience adapters remain outside this implementation proof. The proved property
is soundness of acceptance; completeness (accepting every valid certificate)
has not been proved.

## Checked arithmetic, codecs, algebra and graphs

`runtime/int32` and `runtime/int64` provide `checked_add`, `checked_sub` and
`checked_mul`. `Some(value)` is the exact mathematical result; `None` means the
result is outside the destination range. Both integer preludes prove these
contracts, including intermediate-operation safety in the machine prelude.
`runtime/conversion` provides all 12 directed conversions among `Int`, `UInt`,
`Int64` and `UInt64`. The nine fallible conversions use `checked_`, such as
`checked_int_to_uint` and `checked_int64_to_int`, and return `Option`.
The three unconditional widenings (`int_to_int64`, `uint_to_int64`,
`uint_to_uint64`) return their native destination values directly, using core's
casts. `can_*` proves the exact range decision; `converted_*` specifies value
preservation (wrap a widening result in `Some` in that specification).
These functions take native types; MoonBit does not allow this package to add
public methods directly to builtin numeric types. Native casts are currently rejected
by the proof frontend, so their correspondence is tested with independent
`BigInt` arithmetic rather than assumed. `just conversion-capabilities` records
this boundary, including unsupported UInt16 lowering.

`runtime/bytes` uses MoonBit type names: `byte_to_bytes` and
`{uint16,uint,uint64}_to_{le,be}_bytes`, following core's `to_le_bytes` /
`to_be_bytes` convention. `read_byte` and `read_{uint16,uint,uint64}_{le,be}`
take `(data : BytesView, offset : Int)` and return the native value as `T?`.
For sequential parsing, `decode_byte` and `decode_{uint16,uint,uint64}_{le,be}`
return `Decoded[T]?`, with `value` and `next_offset` relative to the view. Negative,
overflowing and truncated offsets return `None`; trailing bytes are permitted.
`read_end` proves the bounds check and exact consumed length. `encoding` proves
LE/BE roundtrips, octet ranges and lengths; `encoding/bitvector` connects these to
Bv8/Bv16/Bv32/Bv64, and `runtime/bytes.byte_model` connects native Byte to Bv8.
Native codec values, UInt16 casts and view-offset handling are differential-tested;
the codec bodies have no universal value-correspondence proof. UInt16 uses its
natural MoonBit runtime type. Encoders return fresh immutable `Bytes`.

`algebra` defines `associative`, `identity`, `commutative` and `monoid` over a
supplied pure operation, and structural models over `runtime/list.List`.
`fold_split` needs no algebraic assumptions; `fold_partitions` and
`fold_directions` require a monoid; `reorder_partitions` also requires
commutativity. `map_identity` and `map_composition` are proved by induction.
Runtime `List::map(f)` and `List::fold(init=initial, f)` match core/list's
`raise?` callbacks: they run left to right and propagate an error immediately.
`List::from_iter` consumes a core `Iter` in order. Core differential tests,
shrinking, law, callback error and long-list tests cover these APIs. Effects in runtime callbacks are
outside the pure model. No law is assumed for an arbitrary operation.

`runtime/graph.Graph::from_array(edges, vertex_count=n)` validates a directed graph over
`0..<vertex_count` with nonnegative Int weights, self-loops and parallel edges.
It copies input edges. `Graph::new(vertex_count=n)` creates vertices without edges;
`from_iter(edges, vertex_count=n)` consumes a core `Iter`. `iter()` / `to_array()`
traverse edges in source-vertex order, preserving input order within each source.
Constructors and searches return values directly and `raise GraphError`, so they
compose with MoonBit's `try ... catch`. `bfs(source)` minimizes edge count; `dijkstra(source)`
minimizes weight using the existing FIFO and minimum-priority queues. Results
provide `distance(vertex)` and a fresh `path_to(vertex)` including both endpoints.
Invalid or unreachable lookup vertices return `None`; invalid sources return an
error. Dijkstra rejects a reachable shortest distance beyond Int max, while an
overflowing detour does not reject a representable alternative.
`check_bfs` / `check_dijkstra` independently validate paths, edge inequalities and
closure of the reachable set. These diagnostic checks take O(V(V+E)) time in the
worst case by following predecessor chains and scanning edges; algorithms do not
run them implicitly. Graphs own immutable CSR storage. The checker reads the actual
edge, distance and parent FixedArrays without an unproved array conversion, and
requires no correctness assumption about the producer's certificate.

`graph` proves path concatenation/decomposition, weight additivity, closure in
`fset`, and shortest-path certificates from feasible distance labels. Its logical
path stores successors (source omitted, target included); runtime `path_to`
includes the source. The executable checker's `path` instead uses a reverse
`List[Int]` of indices into the actual edge array, distinguishing parallel edges.
`path_cost` sums mathematical integers: edge count for BFS, weights for Dijkstra.
Induction on parent chains establishes attaining witnesses; induction on arbitrary
paths establishes lower bounds and closure. Both producers and checkers are also
tested against an independent Floyd–Warshall oracle, including zero cycles,
disconnected vertices, overflow and corrupted certificates. The BFS/Dijkstra
producer bodies, CSR construction and `path_to` conversion to a mutable array
remain differential-tested, not formally proved. `examples/toolkit/checked_graph.mbt`
consumes the public checker contracts to prove shortestness at any queried vertex. `examples/toolkit` shows the runtime APIs and
composes arithmetic, aggregation and finite-set proof contracts.

Run `just quickcheck-graph js` (or `wasm`, `wasm-gc`, `native`) for graph properties.
`just verify-graph` also runs all graph tests in debug/release on all four backends,
the complete checker bodies, logical laws and client contracts under both integer models,
and negative proof controls. In the triangle example, BFS certifies the direct
one-edge route while weighted shortestness certifies the two-edge route of cost 2
over the direct route of cost 3. The negative control must reject the cost-3 route
as shortest; a path witness alone is insufficient.
