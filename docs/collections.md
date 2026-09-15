# Collections and array updates

[日本語](collections.ja.md) | [README](../README.md)

## Runtime collection API

Own types provide methods: `List::new()`, `Stack::new()`, `Queue::new()`,
`IntMinQueue::new()`, `IntSet::new()`, and `Tree::new()`. Updates return new
persistent values; existing versions remain usable. `IntMinQueue` is explicitly
an Int-only minimum queue with duplicates; `IntSet` stores unique Int keys.
The existing free functions remain aliases of the same contracted implementations.

```moonbit
// Import "mizchi/veri/runtime/queue".
test "persistent queue and Iter" {
  let original : @queue.Queue[Int] = @queue.Queue::new()
  let queue = original.push(1).push(2)
  assert_true(original.is_empty())
  assert_eq(queue.iter().map(x => x * 2).to_array(), [2, 4])
}
```

`iter()` creates independent consuming traversal state without first converting
the collection to an array: list order, stack top first, queue FIFO order,
ascending minimum-queue/set order, and inorder for trees. Iteration and array
conversions are runtime-tested; their correspondence has no proof contract.
List methods follow core naming: `prepend`, `concat`, and `rev`; the free aliases
`cons(value, list)`, `append(left, right)`, and `reverse(list)` remain available.

## FixedArray updates and ranges

`runtime/array` directly updates built-in `FixedArray[T]` values. Ranges are
specified by `Range { start, count }`, meaning `[start, start + count)`. Every update
returns `true` on success and `false` for invalid indices or ranges. Invalid
operations leave the array unchanged; an empty range at the end is valid.
`Range` is a small `#valtype` record. Its named fields prevent confusing offsets
and counts, while positional function calls remain usable in verified code.
The current frontend rejects labelled calls in contracted bodies. A `Range`
can contain invalid values; constructing it does not assert any bounds.

| API | Behavior |
| --- | --- |
| `valid_range(length, range)` | Validate endpoints without overflowing, including for extreme invalid inputs |
| `set(array, index, value)` | Write one cell |
| `swap(array, left, right)` | Exchange two cells; equal indices are valid |
| `fill(array, value, range)` | Fill a range |
| `blit(source, target, source_range, target_start)` | Copy between arrays, allowing overlapping source and destination |
| `blit_disjoint(source, target, source_range, target_start)` | Verified copy between **distinct arrays** |
| `copy_within(array, source_range, target_start)` | Copy within one array, including overlapping ranges, using the original source values |

`set` and `swap` take constant time; range updates take O(count) time and constant
auxiliary space. `copy_within` copies backwards when moving towards higher
indices, without allocating a temporary array. This states algorithmic costs,
not measured performance parity with core. `blit` checks object identity and
selects `copy_within` for the same array or `blit_disjoint` for distinct arrays.
The dispatcher is runtime-tested and has no proof contract. Verified callers
choose `copy_within` or `blit_disjoint`; Why3 rejects passing aliases to the latter.
`range_in_bounds(length, start, count)` is a **proof-only** predicate over
mathematical endpoints. Use `valid_range(length, range)` at runtime.

```moonbit
// Import "mizchi/veri/runtime/array".
test "range updates" {
  let xs : FixedArray[Int] = [0, 1, 2, 3]
  assert_true(@array.fill(xs, 9, { start: 1, count: 2 }))
  assert_true(@array.copy_within(xs, { start: 0, count: 3 }, 1))
  assert_eq(xs, [0, 0, 9, 9])
}
```

The runtime proofs cover range validation, safe indexing, arithmetic bounds and
loop termination under both integer preludes. They also establish the value
written by `set`, the exchanged values through local assertions in `swap`, the
whole filled range, and equality of copied cells with the distinct source in
`blit_disjoint`. The public `swap` and `copy_within` contracts expose success/bounds only.
`examples/bridges.fill_and_read` proves that a caller can compose `fill` and `get`.

`arrays/range` defines full before/after specifications: `unchanged_outside`,
`filled`, `copied`, and `exchange`. Its seven proved lemmas cover single writes,
swap/undo, empty operations, and extending a fill or copy by one cell. The models
use mathematical indices and [Why3 map](https://why3.org/stdlib/map.html)
range equality/exchange. `copied` always reads the **pre-state** source, including
for overlap. These lemmas do not establish full runtime correspondence.

The current compiler has no usable `old(...)` contract expression, and
`proof_let` snapshots cause a compiler assertion failure. Consequently, complete
before/after correspondence, preservation outside the written range, unchanged
state on failure, and overlap copying are checked against snapshot references
with QuickCheck; they are **not universally proved for the runtime functions**.
The eight array-update properties run 1,000 cases each, including operation traces,
full-width indices and nearby valid ranges, with core tuple/array shrinkers.
A deliberately incorrect forward copy is falsified and shrunk to a three-cell
overlap. Negative proof controls reject wrong filled values, overflowing ranges,
out-of-range writes in the model, and copying from an already modified source.

`just array-capabilities` records the compiler limitations and checks alias
rejection in `_build/array-capabilities.json`; it is included in `just verify`.
Predicates wrapping array reads in local proof annotations also avoid the
compiler treating mutating functions as Why3 ghost code. No new assumed
contracts or custom axioms are introduced. Implementation status and proof boundaries are recorded in [TODO.md](../TODO.md) in the repository.

## Collection models and implementations

| Logical package | Bundled Why3 theories | Interpretation |
| --- | --- | --- |
| `seq` | `seq.Seq`, `Reverse`, `Mem`, `Occ`, `Permut` | Finite sequences with mathematical lengths and indices |
| `list` / `list/indexed` | `list.List`, `Length`, `Append`, `Reverse`, `NthNoOpt`, `NumOcc` | Inductive lists, with optional indexing/counting imports |
| `list/conversions` | `seq.OfList`, `seq.ToList` | Conversion between logical lists and sequences |
| `bag` | `bag.Bag` | Multisets; union adds counts and difference truncates at zero |
| `fmap` | `fmap.Fmap` | Finite maps with a finite-set domain |
| `bintree` | `bintree.Tree`, `Size`, `Height`, `Occ`, `Inorder`, `Preorder` | Binary trees and their content/traversal models |

Logical lengths, counts, and indices use unbounded `integer.Integer`.
Use `seq.get/update` with `0 <= index < length`, and `slice(start, stop)` with
`0 <= start <= stop <= length`; `stop` is exclusive. Logical list `head/tail`
require a nonempty list, and `list/indexed.get(index, xs)` needs an in-range
index. `fmap.find` is meaningful only when `mem(key, map)` holds. These logical
operations do not perform runtime bounds checks; values outside their specified
domains are unspecified.

**`runtime/*` contains independent contracted implementations, not aliases of core.**
The packages implement persistent data structures. Recursive models
connect their actual constructors to Why3 lists, bags, and trees. The stack and
queue APIs follow Why3's LIFO/FIFO specifications; the priority queue follows
the minimum/multiplicity specification. Why3's abstract mutable `val` APIs are
not imported as executable implementations.

Direct wrappers around core were also tested. With the installed toolchain,
`core/list.length`, `core/queue.peek`, `core/immut/priority_queue.push`, and
`core/immut/sorted_set.contains` fail with `Error 4207` inside contracted bodies.
`just core-capabilities` reproduces this and first checks ordinary type correctness.
[MoonBit verification](https://docs.moonbitlang.com/en/latest/language/verification.html)
restricts calls from contracted bodies. `#proof_import` connects logical operations;
it does not prove the corresponding core implementation. Direct reuse with a
correspondence proof needs proof-callable contracts in core or compiler support.
These contracts have not been replaced with `#proof_axiomatized` assumptions.


| Runtime package | Operations and representation | Cost |
| --- | --- | --- |
| `runtime/list` | `empty/cons/uncons/is_empty/append/reverse/length`; immutable linked spine | Basic operations O(1); append/reverse/length O(n) |
| `runtime/stack` | `empty/push/pop/peek/is_empty`; linked cells also used as pop results | O(1) |
| `runtime/queue` | `empty/push/pop/peek/is_empty`; front list and reversed back list | Push/peek O(1); pop amortized O(1), worst-case O(n) |
| `runtime/pqueue` | `empty/push/pop/peek/is_empty`; Int two-pass pairing heap, duplicates retained | Push/peek O(1); pop O(k) for k root children, worst-case O(n) |
| `runtime/bintree` | `empty/node/inorder/to_array`; generic binary tree | Constructors O(1); traversal O(n) |
| `runtime/bintree/search` | `empty/insert/contains`; Int red-black tree without duplicates | Insert/contains O(log n) |

Costs describe states built through the public APIs and are not formally proved. Queue updates
normalize the front list, so repeated peeks do not repeat reversal. Amortized costs
for the queue apply to a single update history; branching from old
snapshots can repeat work. The priority queue follows the
[pairing heap](https://www.cs.cmu.edu/~sleator/papers/Pairing-Heaps.htm): pair adjacent
children from left to right, then merge the paired roots from right to left.
Both passes are tail recursive, with proofs of termination, contents and ordering.
Pairing and linking construct the resulting cells directly, avoiding temporary roots.
The search tree follows
[Okasaki's insertion algorithm](https://www.cambridge.org/core/journals/journal-of-functional-programming/article/redblack-trees-in-a-functional-setting/62BC5EA75A2C95E3F6EE95AE3DADF0E5).
These differ from core's complete binary heap and size-balanced search tree.

BST `valid(tree)` retains its strict search-order meaning: `empty` establishes it
and `insert` preserves it. Insertion, including rotations, and lookup have proofs
of order, membership preservation, and search results. Red-black invariants
(black root, no red-red edge, equal black heights) are checked by shrinking
QuickCheck properties and long ascending/descending tests. Formal proofs of color
balance and complexity, and deletion, are not implemented.

The search-tree API now uses an opaque `@search.IntSet` with internal colors.
Code passing `@tree.Tree[Int]` directly must instead construct a search tree with
`@search.empty()` and `insert`, enumerate with `@search.to_array(tree)`, and use
`@search.model` in contracts. The generic `runtime/bintree.Tree[T]` remains available
for arbitrary shapes. List length uses tail recursion; tree inorder uses a
continuation list for linear traversal. Its left branch is tail-recursive, while
its right branch and List append still use the call stack.
Direct `Tree::to_array()` uses an explicit stack for deep trees in either direction
and avoids an intermediate linked list. Independent QuickCheck models and
20,000-level trees test this runtime conversion.
Stack/Queue/IntMinQueue/IntSet use `#valtype` wrappers, and small operations
use `#inline` to reduce wrapper allocations. Updates also use `#owned` to avoid
unnecessary reference-count operations without changing the existing content/order
contracts. A Stack cell is already `(value, rest)?`, so pop allocates no extra tuple.
`proof_require`, `proof_ensure`, `proof_assert`, and `.mbtp` specifications
are not runtime checks.

`pop/uncons/peek` return `None` for empty inputs. List `length` requires its
mathematical result to fit in an Int (at most 2,147,483,647), including under
the machine-integer prelude. Array conversion helpers (`from_array/to_array`)
are covered by runtime properties but have no correspondence contracts yet.
Persistence preserves the container's structure; stored values may themselves
be mutable. `examples/collections` demonstrates contract composition across
modules, and `just prove-collections-machine` checks the same collection
implementations and examples using machine integers.
