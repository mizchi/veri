# コレクションのチューニング / Collection tuning

2026-09-15、Apple M5。直前の測定を基準に、List の所有権注釈、Stack の格納形式、Queue の正規化と peek、PQueue のアルゴリズムを調整した。Tree には中間リストを作らない `to_array()` を追加した。

Recorded on 2026-09-15 on Apple M5. Changes cover List ownership annotations, Stack representation, Queue normalization and peek, and the PQueue algorithm. Tree gains a direct `to_array()` conversion without an intermediate list.

**全処理・全バックエンドで core 以下という条件は未達。/ The universal no-slowdown target is not met.**

2,048要素では、PQueue の昇順入力が全バックエンドで2.27〜4.89倍速くなった。native の List 反転は1.58倍、Stack は1.53倍、Queue は1.30倍。昇順入力の改善を優先して pairing heap を採用したが、シャッフル入力は native の256要素で約11%、wasm の256 / 2,048要素で約42% / 23%遅くなった。wasm-gc の Stack も2,048要素で約9%遅い。全ケースの退行を解消した最適化ではない。

At n=2048, ascending PQueue workloads are 2.27–4.89× faster across all backends. Native List reversal improves 1.58×, Stack 1.53× and Queue 1.30×. The pairing heap favors the ascending workload improvement, with tradeoffs: shuffled inputs take about 11% longer on native at n=256 and 42% / 23% longer on wasm at n=256 / 2048. The wasm-gc Stack also takes about 9% longer at n=2048. This change does not eliminate regressions in every case.

直接 `Tree::to_array()` は native の平衡木で core 比0.91倍だが、JS・wasm-gc の左に偏った木では従来の `inorder().to_array()` より遅い。中間の出力リストを省き、両方向の深い木を処理できる別の経路として提供する。

Direct `Tree::to_array()` reaches 0.91× core time for the native balanced tree, but is slower than the original `inorder().to_array()` path for left-skewed trees on JS and wasm-gc. It provides a separate conversion path that avoids the intermediate output list and handles deep trees in either direction.

## 変更 / Changes

- List: `concat/rev/to_array` と反転補助関数に所有権注釈を追加し、参照管理を減らす。/ Ownership annotations reduce reference management.
- Stack: `(value, rest)?` をセルとして保存し、pop はそのセルを返す。API の名前・引数・戻り値を保ち、内部表現を value enum に変更した。/ Cells are already pop results; method signatures remain unchanged while the representation becomes a value enum.
- Queue: 前方リストを直接照合して正規化する。空の前方リストからの peek は後方リストの末尾を調べ、反転結果を確保しない。/ Normalize by matching the front directly; the empty-front peek fallback finds the oldest deferred value without allocating a reversed list.
- PQueue: skew heap から two-pass pairing heap に変更。結合結果を直接構築して一時的な根を省き、両走査を末尾再帰にする。最小値・重複・永続性の仕様を維持する。/ A two-pass pairing heap constructs merged cells directly and uses tail recursion; minimum, multiplicity and persistence behavior are preserved.
- Tree: 明示的なスタックで直接配列化する。従来の `inorder().to_array()` の計測は残す。/ Direct array conversion uses an explicit stack; the original inorder-plus-list-conversion benchmarks remain.

## 測定条件 / Method

release、256 / 2,048要素。実装の順序を逆転した2回の測定、各回5バッチ。入力生成と出力一致の検査は計測外。各バックエンドを順に測定し、測定中はこの作業のテストや prover を動かしていない。

Release builds at 256 and 2,048 elements. Two measurement passes reverse implementation order, each with five calibrated batches. Input generation and exact output checks are outside timing. Backends run sequentially, without this task running tests or provers concurrently.

従来の12処理・30比較は処理内容と測定順を維持した。Tree の直接配列化2処理・4比較を最後に追加し、現在は14処理・34比較・124サマリー。codec・graph・map/fold は対象外。

The original 12 workloads and 30 comparisons retain their bodies and order. Two direct tree workloads append four comparisons, giving 14 workloads, 34 comparisons and 124 summaries. Codec, graph, and map/fold are outside this benchmark suite.

時間は2回のバッチ中央値の平均（µs）。変更前 / 変更後は veri の実時間の比で、1超なら改善。veri/core は1未満なら core より速い。別時点の測定なので、未変更の BST などにも変動がある。core の時間も変動し、2回の比率の幅は信頼区間ではない。

Times are the mean of two batch medians in µs. Before/after divides veri times, so values above 1 indicate improvement. Veri/core below 1 means faster than core. Separate runs also vary for unchanged code, including the BST; core timings vary too. Paired ranges are not confidence intervals.

Queue の repeated-peek は同じキューの読み取りで、コンパイラによるループ外への移動を含み得る。単一呼び出しの遅延比ではない。Tree の core 比較は同じ整列済みの値の列挙。可変の core 実装にはスナップショットのコピーを加えない。これらは実装・表現・確保を含む比較で、proof 単体の追加コストではない。

Repeated queue peeks can be hoisted and do not measure isolated call latency. Tree compares enumeration of the same ordered values. Mutable core baselines incur no simulated snapshot copying. These compare implementations, representations and allocations, rather than proof-contract overhead alone.

## 共通30比較の判定 / The same 30 comparisons

各セルは「両測定順で core 以下 / 両方で遅い / 境界をまたぐ」。新規4比較は別欄。/ Cells show within / slower / inconclusive over both measurement orders; new comparisons are separate.

| Backend | Before (30) | After (30) | New direct tree (4) |
| --- | ---: | ---: | ---: |
| native | 10 / 19 / 1 | 10 / 18 / 2 | 2 / 2 / 0 |
| js | 13 / 16 / 1 | 12 / 16 / 2 | 0 / 4 / 0 |
| wasm | 12 / 16 / 2 | 14 / 15 / 1 | 0 / 4 / 0 |
| wasm-gc | 14 / 15 / 1 | 16 / 13 / 1 | 2 / 2 / 0 |

## veri の変更前 → 変更後 / Before → after veri time

各セルは µs の「前 → 後（前 / 後）」、同一処理のみ。未変更部分の測定値も省略せず掲載する。/ Each cell is before → after µs (before/after), for identical workloads. Measurements of unchanged code are included.

### n = 256

| Workload | native | js | wasm | wasm-gc |
| --- | ---: | ---: | ---: | ---: |
| list/reverse-to-array | 1.62 → 1.04 (1.56×) | 1.08 → 1.13 (0.95×) | 6.08 → 5.87 (1.04×) | 0.65 → 0.65 (1.01×) |
| list/append-to-array | 2.99 → 2.38 (1.26×) | 4.07 → 4.19 (0.97×) | 7.49 → 7.46 (1.01×) | 1.37 → 1.35 (1.01×) |
| list/length | 0.31 → 0.31 (1.00×) | 0.21 → 0.22 (0.96×) | 0.47 → 0.51 (0.91×) | 0.22 → 0.22 (1.00×) |
| stack/build-drain | 1.98 → 1.20 (1.64×) | 1.69 → 1.73 (0.97×) | 9.15 → 5.02 (1.82×) | 0.90 → 0.91 (0.99×) |
| queue/build-drain | 4.49 → 3.77 (1.19×) | 2.87 → 2.89 (0.99×) | 15.65 → 13.21 (1.18×) | 1.85 → 1.80 (1.03×) |
| queue/repeated-peek | 0.11 → 0.10 (1.05×) | 0.05 → 0.06 (0.94×) | 0.21 → 0.20 (1.04×) | 0.14 → 0.13 (1.07×) |
| pqueue/build-drain-shuffled | 24.98 → 27.67 (0.90×) | 12.62 → 9.64 (1.31×) | 58.74 → 83.46 (0.70×) | 9.34 → 8.70 (1.07×) |
| bst/build-find-shuffled | 30.43 → 30.49 (1.00×) | 20.27 → 21.76 (0.93×) | 63.12 → 70.30 (0.90×) | 10.85 → 10.62 (1.02×) |
| pqueue/build-drain-ascending | 26.99 → 13.13 (2.06×) | 15.07 → 5.84 (2.58×) | 69.17 → 41.57 (1.66×) | 9.26 → 4.54 (2.04×) |
| bst/build-find-ascending | 37.04 → 38.59 (0.96×) | 28.72 → 31.29 (0.92×) | 81.67 → 89.07 (0.92×) | 12.37 → 12.52 (0.99×) |
| tree/inorder-to-array-balanced | 2.09 → 1.56 (1.34×) | 1.95 → 2.11 (0.92×) | 7.72 → 6.26 (1.23×) | 0.85 → 0.83 (1.03×) |
| tree/inorder-to-array-left-skewed | 2.08 → 1.48 (1.40×) | 1.93 → 2.12 (0.91×) | 6.85 → 5.89 (1.16×) | 1.01 → 0.95 (1.06×) |

### n = 2048

| Workload | native | js | wasm | wasm-gc |
| --- | ---: | ---: | ---: | ---: |
| list/reverse-to-array | 13.51 → 8.53 (1.58×) | 10.19 → 10.62 (0.96×) | 48.51 → 42.52 (1.14×) | 6.01 → 5.99 (1.00×) |
| list/append-to-array | 26.02 → 21.24 (1.23×) | 35.37 → 36.76 (0.96×) | 59.26 → 58.60 (1.01×) | 13.14 → 13.01 (1.01×) |
| list/length | 2.41 → 2.42 (1.00×) | 1.61 → 1.65 (0.98×) | 3.46 → 3.71 (0.93×) | 1.77 → 1.79 (0.99×) |
| stack/build-drain | 14.85 → 9.74 (1.53×) | 14.87 → 14.93 (1.00×) | 64.67 → 39.68 (1.63×) | 7.06 → 7.71 (0.92×) |
| queue/build-drain | 37.81 → 28.99 (1.30×) | 24.83 → 25.40 (0.98×) | 116.82 → 102.03 (1.14×) | 14.35 → 13.91 (1.03×) |
| queue/repeated-peek | 0.56 → 0.59 (0.96×) | 0.51 → 0.51 (1.02×) | 1.45 → 1.45 (1.00×) | 1.14 → 0.96 (1.19×) |
| pqueue/build-drain-shuffled | 327.74 → 294.17 (1.11×) | 250.76 → 126.77 (1.98×) | 712.62 → 876.67 (0.81×) | 104.29 → 105.98 (0.98×) |
| bst/build-find-shuffled | 421.67 → 397.70 (1.06×) | 213.07 → 260.17 (0.82×) | 788.89 → 855.10 (0.92×) | 131.08 → 124.17 (1.06×) |
| pqueue/build-drain-ascending | 339.81 → 105.03 (3.24×) | 249.95 → 51.15 (4.89×) | 764.60 → 337.17 (2.27×) | 117.09 → 37.81 (3.10×) |
| bst/build-find-ascending | 418.15 → 418.12 (1.00×) | 262.82 → 340.10 (0.77×) | 909.31 → 968.98 (0.94×) | 180.64 → 184.64 (0.98×) |
| tree/inorder-to-array-balanced | 18.33 → 12.38 (1.48×) | 16.81 → 18.09 (0.93×) | 54.38 → 47.55 (1.14×) | 7.36 → 7.18 (1.03×) |
| tree/inorder-to-array-left-skewed | 16.86 → 10.92 (1.54×) | 16.35 → 17.58 (0.93×) | 50.96 → 44.08 (1.16×) | 7.75 → 7.41 (1.05×) |

## 新 API / Direct Tree::to_array()

n=2048。新しい経路なので旧 API の速度向上とは数えない。各セルは veri の µs / veri/core 比。/ New conversion path, not counted as a speedup of the old API. Cells show veri µs / veri/core at n=2048.

| Shape | native | js | wasm | wasm-gc |
| --- | ---: | ---: | ---: | ---: |
| balanced | 4.10 / 0.91× | 17.31 / 1.11× | 15.12 / 1.08× | 4.70 / 0.98× |
| left-skewed | 7.01 / 1.57× | 24.02 / 1.54× | 25.47 / 1.82× | 11.64 / 2.43× |

## 検証 / Validation

- 576 tests pass on js, wasm, wasm-gc and native, in both debug and release; shrinking QuickCheck properties include persistent snapshots and independent core/reference results.
- List 11, Stack 6, Queue 12 and PQueue 17 proof goals pass under both default and machine-integer preludes. PQueue termination uses the mathematical size of the remaining forest.
- False LIFO/FIFO/minimum claims remain unproved in the negative controls. A timeout on the false goal is not a concrete counterexample. Queue/PQueue process budgets allow their positive proofs to finish before evaluating the false control; solver limits and required failure matching remain unchanged.
- Tree conversion agrees with a recursive reference under shrinking QuickCheck and handles 20,000-level left and right trees. This conversion is runtime-tested; it has no formal correspondence contract.
- Formatting and warning-free checking, 16 tooling tests, and package-consumer checks pass. Both README quickstarts execute and prove; the packaged Stack and Tree APIs execute.

## 再実行と記録 / Reproduction and records

```sh
just bench-backends
just bench-check native 1.0
```

`bench-check` は片方でも上限を超えた場合や判定保留で失敗する。下表の上限判定は保存した最終測定に同じ規則を適用したもの。/ `bench-check` fails if either order exceeds the limit, including inconclusive cases. Counts below apply that same rule to the saved final measurements.

| Backend | Comparisons not within 1.0 / total |
| --- | ---: |
| native | 22 / 34 |
| js | 22 / 34 |
| wasm | 20 / 34 |
| wasm-gc | 16 / 34 |

直前の基準測定は `_build/tuning/before/`、今回の生ログ・全精度 JSON は `_build/benchmarks/` に保存した。これらはローカル生成物。以下に全バックエンドの最終測定とソース指紋を記録する。/ Local baseline artifacts are in `_build/tuning/before/`; current raw logs and full-precision JSON are in `_build/benchmarks/`. Final tables and source fingerprints are recorded below.

[2026-09-14の履歴 / Historical snapshot](RESULTS.md) は当時の測定として変更していない。

### Baseline source fingerprints

Runtime SHA-256: dc52bc861817e2f05ff57b1b05cac236b30329d690fed613bcfa8c84423af8bb.
Workloads SHA-256: 5021b923fc43502390e3e698f34b03b3af0f5a16461eff31635005169f5e4504.

| Backend | Baseline timestamp (UTC) |
| --- | --- |
| native | 2026-09-15T01:01:13.174Z |
| js | 2026-09-15T01:02:33.294Z |
| wasm | 2026-09-15T01:03:53.163Z |
| wasm-gc | 2026-09-15T01:05:15.396Z |

## native — final measurements

Recorded: 2026-09-15T01:51:36.536Z. Target: native, release.
CPU: Apple M5. OS: darwin 25.6.0 (arm64).
Node: v24.21.0. Repository base: 4085aae7f252d0e52a8cec98763d423ce6abd611 (working tree dirty: true).
Moon: moon 0.1.20260904 (94521db 2026-09-04) ~/.moon/bin/moon moonc v0.10.12+1634b282e (2026-09-07) ~/.moon/bin/moonc moonrun 0.1.20260904 (94521db 2026-09-04) ~/.moon/bin/moonrun  Feature flags enabled: rr_moon_mod,rr_moon_pkg.
Installed core source SHA-256: 03e2587990f077d1d1c9ca5701bdc0d28f0bd458571af0f2954af826bbe412f5.
Runtime source SHA-256: 96dc57055f2b0ece94872251c617bc07a7e4414108a6d2b4a085009ad01acbe1.
Benchmark source SHA-256: 88be7d2c789dfe09f8f347514977c4d1df471c121234fca94bb97504778f3958.

Times are microseconds per complete workload: the mean of two batch medians.
Each pass contains five calibrated batches; implementation order is reversed in pass 2.
Ratios are veri/core (above 1 means slower). The range shows the two paired ratios, not a confidence interval.
These measurements compare the current data structures, including representation and allocation costs; they do not isolate proof-contract overhead.

| Workload | n | Core baseline | veri µs | core µs | Ratio | Paired range | Compared with 1.0 |
| --- | ---: | --- | ---: | ---: | ---: | ---: | --- |
| list/reverse-to-array | 256 | core-list | 1.040 | 1.948 | 0.53× | 0.53–0.53 | within |
| list/append-to-array | 256 | core-list | 2.381 | 2.547 | 0.93× | 0.93–0.94 | within |
| list/length | 256 | core-list | 0.314 | 0.322 | 0.97× | 0.95–1.00 | inconclusive |
| stack/build-drain | 256 | core-list | 1.205 | 1.019 | 1.18× | 1.18–1.18 | slower |
| stack/build-drain | 256 | core-array | 1.205 | 0.384 | 3.13× | 3.00–3.28 | slower |
| queue/build-drain | 256 | core-queue | 3.773 | 0.980 | 3.85× | 3.82–3.87 | slower |
| queue/repeated-peek | 256 | core-queue | 0.100 | 0.009 | 11.28× | 11.28–11.29 | slower |
| pqueue/build-drain-shuffled | 256 | core-immut-pqueue | 27.666 | 53.973 | 0.51× | 0.51–0.52 | within |
| pqueue/build-drain-shuffled | 256 | core-pqueue | 27.666 | 6.599 | 4.19× | 4.13–4.26 | slower |
| bst/build-find-shuffled | 256 | core-immut-sorted-set | 30.491 | 29.398 | 1.04× | 1.04–1.04 | slower |
| pqueue/build-drain-ascending | 256 | core-immut-pqueue | 13.127 | 53.432 | 0.25× | 0.24–0.25 | within |
| pqueue/build-drain-ascending | 256 | core-pqueue | 13.127 | 3.261 | 4.03× | 4.02–4.03 | slower |
| bst/build-find-ascending | 256 | core-immut-sorted-set | 38.592 | 43.544 | 0.89× | 0.88–0.90 | within |
| tree/inorder-to-array-balanced | 256 | core-immut-sorted-set | 1.561 | 0.671 | 2.33× | 2.29–2.36 | slower |
| tree/inorder-to-array-left-skewed | 256 | core-immut-sorted-set | 1.479 | 0.634 | 2.33× | 2.32–2.35 | slower |
| tree/to-array-balanced | 256 | core-immut-sorted-set | 0.621 | 0.636 | 0.98× | 0.97–0.98 | within |
| tree/to-array-left-skewed | 256 | core-immut-sorted-set | 1.027 | 0.639 | 1.61× | 1.59–1.62 | slower |
| list/reverse-to-array | 2048 | core-list | 8.530 | 15.899 | 0.54× | 0.53–0.54 | within |
| list/append-to-array | 2048 | core-list | 21.235 | 21.199 | 1.00× | 0.99–1.01 | inconclusive |
| list/length | 2048 | core-list | 2.422 | 2.446 | 0.99× | 0.99–0.99 | within |
| stack/build-drain | 2048 | core-list | 9.738 | 7.790 | 1.25× | 1.25–1.25 | slower |
| stack/build-drain | 2048 | core-array | 9.738 | 2.020 | 4.82× | 4.57–5.10 | slower |
| queue/build-drain | 2048 | core-queue | 28.990 | 7.076 | 4.10× | 4.09–4.10 | slower |
| queue/repeated-peek | 2048 | core-queue | 0.585 | 0.009 | 67.71× | 65.93–69.57 | slower |
| pqueue/build-drain-shuffled | 2048 | core-immut-pqueue | 294.166 | 760.333 | 0.39× | 0.39–0.39 | within |
| pqueue/build-drain-shuffled | 2048 | core-pqueue | 294.166 | 91.004 | 3.23× | 3.18–3.28 | slower |
| bst/build-find-shuffled | 2048 | core-immut-sorted-set | 397.701 | 365.336 | 1.09× | 1.08–1.09 | slower |
| pqueue/build-drain-ascending | 2048 | core-immut-pqueue | 105.029 | 747.552 | 0.14× | 0.14–0.14 | within |
| pqueue/build-drain-ascending | 2048 | core-pqueue | 105.029 | 26.053 | 4.03× | 4.01–4.06 | slower |
| bst/build-find-ascending | 2048 | core-immut-sorted-set | 418.123 | 521.683 | 0.80× | 0.80–0.80 | within |
| tree/inorder-to-array-balanced | 2048 | core-immut-sorted-set | 12.382 | 4.507 | 2.75× | 2.73–2.77 | slower |
| tree/inorder-to-array-left-skewed | 2048 | core-immut-sorted-set | 10.922 | 4.460 | 2.45× | 2.43–2.47 | slower |
| tree/to-array-balanced | 2048 | core-immut-sorted-set | 4.096 | 4.483 | 0.91× | 0.90–0.93 | within |
| tree/to-array-left-skewed | 2048 | core-immut-sorted-set | 7.006 | 4.470 | 1.57× | 1.53–1.60 | slower |

`within` means both paired ratios are ≤ 1; `slower` means both are > 1; otherwise `inconclusive`.

## js — final measurements

Recorded: 2026-09-15T01:55:35.324Z. Target: js, release.
CPU: Apple M5. OS: darwin 25.6.0 (arm64).
Node: v24.21.0. Repository base: 4085aae7f252d0e52a8cec98763d423ce6abd611 (working tree dirty: true).
Moon: moon 0.1.20260904 (94521db 2026-09-04) ~/.moon/bin/moon moonc v0.10.12+1634b282e (2026-09-07) ~/.moon/bin/moonc moonrun 0.1.20260904 (94521db 2026-09-04) ~/.moon/bin/moonrun  Feature flags enabled: rr_moon_mod,rr_moon_pkg.
Installed core source SHA-256: 03e2587990f077d1d1c9ca5701bdc0d28f0bd458571af0f2954af826bbe412f5.
Runtime source SHA-256: 96dc57055f2b0ece94872251c617bc07a7e4414108a6d2b4a085009ad01acbe1.
Benchmark source SHA-256: 88be7d2c789dfe09f8f347514977c4d1df471c121234fca94bb97504778f3958.

Times are microseconds per complete workload: the mean of two batch medians.
Each pass contains five calibrated batches; implementation order is reversed in pass 2.
Ratios are veri/core (above 1 means slower). The range shows the two paired ratios, not a confidence interval.
These measurements compare the current data structures, including representation and allocation costs; they do not isolate proof-contract overhead.

| Workload | n | Core baseline | veri µs | core µs | Ratio | Paired range | Compared with 1.0 |
| --- | ---: | --- | ---: | ---: | ---: | ---: | --- |
| list/reverse-to-array | 256 | core-list | 1.134 | 1.789 | 0.63× | 0.42–0.85 | within |
| list/append-to-array | 256 | core-list | 4.191 | 3.161 | 1.33× | 1.29–1.36 | slower |
| list/length | 256 | core-list | 0.218 | 0.214 | 1.02× | 0.99–1.04 | inconclusive |
| stack/build-drain | 256 | core-list | 1.733 | 1.543 | 1.12× | 1.12–1.13 | slower |
| stack/build-drain | 256 | core-array | 1.733 | 2.601 | 0.67× | 0.66–0.67 | within |
| queue/build-drain | 256 | core-queue | 2.894 | 2.431 | 1.19× | 1.18–1.20 | slower |
| queue/repeated-peek | 256 | core-queue | 0.059 | 0.237 | 0.25× | 0.24–0.25 | within |
| pqueue/build-drain-shuffled | 256 | core-immut-pqueue | 9.642 | 29.810 | 0.32× | 0.32–0.33 | within |
| pqueue/build-drain-shuffled | 256 | core-pqueue | 9.642 | 4.475 | 2.15× | 2.13–2.18 | slower |
| bst/build-find-shuffled | 256 | core-immut-sorted-set | 21.760 | 19.276 | 1.13× | 1.13–1.13 | slower |
| pqueue/build-drain-ascending | 256 | core-immut-pqueue | 5.843 | 29.830 | 0.20× | 0.19–0.20 | within |
| pqueue/build-drain-ascending | 256 | core-pqueue | 5.843 | 2.312 | 2.53× | 2.53–2.53 | slower |
| bst/build-find-ascending | 256 | core-immut-sorted-set | 31.295 | 31.568 | 0.99× | 0.96–1.03 | inconclusive |
| tree/inorder-to-array-balanced | 256 | core-immut-sorted-set | 2.112 | 1.770 | 1.19× | 1.18–1.20 | slower |
| tree/inorder-to-array-left-skewed | 256 | core-immut-sorted-set | 2.119 | 1.790 | 1.18× | 1.17–1.19 | slower |
| tree/to-array-balanced | 256 | core-immut-sorted-set | 2.020 | 1.794 | 1.13× | 1.12–1.13 | slower |
| tree/to-array-left-skewed | 256 | core-immut-sorted-set | 2.837 | 1.793 | 1.58× | 1.58–1.59 | slower |
| list/reverse-to-array | 2048 | core-list | 10.624 | 19.494 | 0.54× | 0.39–0.70 | within |
| list/append-to-array | 2048 | core-list | 36.758 | 30.601 | 1.20× | 1.20–1.20 | slower |
| list/length | 2048 | core-list | 1.651 | 4.015 | 0.41× | 0.40–0.42 | within |
| stack/build-drain | 2048 | core-list | 14.933 | 13.055 | 1.14× | 1.13–1.16 | slower |
| stack/build-drain | 2048 | core-array | 14.933 | 22.203 | 0.67× | 0.67–0.68 | within |
| queue/build-drain | 2048 | core-queue | 25.396 | 19.651 | 1.29× | 1.29–1.29 | slower |
| queue/repeated-peek | 2048 | core-queue | 0.507 | 1.841 | 0.28× | 0.27–0.28 | within |
| pqueue/build-drain-shuffled | 2048 | core-immut-pqueue | 126.774 | 414.428 | 0.31× | 0.30–0.31 | within |
| pqueue/build-drain-shuffled | 2048 | core-pqueue | 126.774 | 53.973 | 2.35× | 2.33–2.37 | slower |
| bst/build-find-shuffled | 2048 | core-immut-sorted-set | 260.170 | 227.087 | 1.15× | 1.13–1.17 | slower |
| pqueue/build-drain-ascending | 2048 | core-immut-pqueue | 51.153 | 398.459 | 0.13× | 0.13–0.13 | within |
| pqueue/build-drain-ascending | 2048 | core-pqueue | 51.153 | 19.157 | 2.67× | 2.67–2.67 | slower |
| bst/build-find-ascending | 2048 | core-immut-sorted-set | 340.100 | 408.858 | 0.83× | 0.83–0.84 | within |
| tree/inorder-to-array-balanced | 2048 | core-immut-sorted-set | 18.089 | 15.494 | 1.17× | 1.17–1.17 | slower |
| tree/inorder-to-array-left-skewed | 2048 | core-immut-sorted-set | 17.578 | 15.705 | 1.12× | 1.12–1.12 | slower |
| tree/to-array-balanced | 2048 | core-immut-sorted-set | 17.310 | 15.532 | 1.11× | 1.11–1.12 | slower |
| tree/to-array-left-skewed | 2048 | core-immut-sorted-set | 24.015 | 15.605 | 1.54× | 1.54–1.54 | slower |

`within` means both paired ratios are ≤ 1; `slower` means both are > 1; otherwise `inconclusive`.

## wasm — final measurements

Recorded: 2026-09-15T01:57:07.055Z. Target: wasm, release.
CPU: Apple M5. OS: darwin 25.6.0 (arm64).
Node: v24.21.0. Repository base: 4085aae7f252d0e52a8cec98763d423ce6abd611 (working tree dirty: true).
Moon: moon 0.1.20260904 (94521db 2026-09-04) ~/.moon/bin/moon moonc v0.10.12+1634b282e (2026-09-07) ~/.moon/bin/moonc moonrun 0.1.20260904 (94521db 2026-09-04) ~/.moon/bin/moonrun  Feature flags enabled: rr_moon_mod,rr_moon_pkg.
Installed core source SHA-256: 03e2587990f077d1d1c9ca5701bdc0d28f0bd458571af0f2954af826bbe412f5.
Runtime source SHA-256: 96dc57055f2b0ece94872251c617bc07a7e4414108a6d2b4a085009ad01acbe1.
Benchmark source SHA-256: 88be7d2c789dfe09f8f347514977c4d1df471c121234fca94bb97504778f3958.

Times are microseconds per complete workload: the mean of two batch medians.
Each pass contains five calibrated batches; implementation order is reversed in pass 2.
Ratios are veri/core (above 1 means slower). The range shows the two paired ratios, not a confidence interval.
These measurements compare the current data structures, including representation and allocation costs; they do not isolate proof-contract overhead.

| Workload | n | Core baseline | veri µs | core µs | Ratio | Paired range | Compared with 1.0 |
| --- | ---: | --- | ---: | ---: | ---: | ---: | --- |
| list/reverse-to-array | 256 | core-list | 5.867 | 7.612 | 0.77× | 0.77–0.78 | within |
| list/append-to-array | 256 | core-list | 7.455 | 9.136 | 0.82× | 0.81–0.82 | within |
| list/length | 256 | core-list | 0.513 | 0.510 | 1.01× | 1.00–1.01 | slower |
| stack/build-drain | 256 | core-list | 5.022 | 5.169 | 0.97× | 0.95–0.99 | within |
| stack/build-drain | 256 | core-array | 5.022 | 2.479 | 2.03× | 2.01–2.04 | slower |
| queue/build-drain | 256 | core-queue | 13.215 | 2.876 | 4.59× | 4.57–4.62 | slower |
| queue/repeated-peek | 256 | core-queue | 0.201 | 0.321 | 0.63× | 0.62–0.63 | within |
| pqueue/build-drain-shuffled | 256 | core-immut-pqueue | 83.458 | 155.876 | 0.54× | 0.52–0.55 | within |
| pqueue/build-drain-shuffled | 256 | core-pqueue | 83.458 | 17.189 | 4.86× | 4.79–4.92 | slower |
| bst/build-find-shuffled | 256 | core-immut-sorted-set | 70.298 | 65.457 | 1.07× | 1.07–1.08 | slower |
| pqueue/build-drain-ascending | 256 | core-immut-pqueue | 41.573 | 158.721 | 0.26× | 0.24–0.28 | within |
| pqueue/build-drain-ascending | 256 | core-pqueue | 41.573 | 10.039 | 4.14× | 4.07–4.22 | slower |
| bst/build-find-ascending | 256 | core-immut-sorted-set | 89.073 | 100.510 | 0.89× | 0.88–0.89 | within |
| tree/inorder-to-array-balanced | 256 | core-immut-sorted-set | 6.263 | 2.023 | 3.10× | 3.07–3.12 | slower |
| tree/inorder-to-array-left-skewed | 256 | core-immut-sorted-set | 5.891 | 2.033 | 2.90× | 2.88–2.92 | slower |
| tree/to-array-balanced | 256 | core-immut-sorted-set | 2.808 | 2.066 | 1.36× | 1.35–1.37 | slower |
| tree/to-array-left-skewed | 256 | core-immut-sorted-set | 3.978 | 2.033 | 1.96× | 1.96–1.96 | slower |
| list/reverse-to-array | 2048 | core-list | 42.519 | 58.962 | 0.72× | 0.72–0.73 | within |
| list/append-to-array | 2048 | core-list | 58.604 | 71.256 | 0.82× | 0.82–0.83 | within |
| list/length | 2048 | core-list | 3.714 | 3.729 | 1.00× | 0.99–1.00 | within |
| stack/build-drain | 2048 | core-list | 39.680 | 38.463 | 1.03× | 1.00–1.06 | slower |
| stack/build-drain | 2048 | core-array | 39.680 | 20.078 | 1.98× | 1.94–2.02 | slower |
| queue/build-drain | 2048 | core-queue | 102.033 | 20.182 | 5.06× | 4.97–5.14 | slower |
| queue/repeated-peek | 2048 | core-queue | 1.447 | 2.356 | 0.61× | 0.59–0.64 | within |
| pqueue/build-drain-shuffled | 2048 | core-immut-pqueue | 876.670 | 1879.303 | 0.47× | 0.46–0.47 | within |
| pqueue/build-drain-shuffled | 2048 | core-pqueue | 876.670 | 196.375 | 4.46× | 4.36–4.57 | slower |
| bst/build-find-shuffled | 2048 | core-immut-sorted-set | 855.100 | 844.415 | 1.01× | 0.99–1.03 | inconclusive |
| pqueue/build-drain-ascending | 2048 | core-immut-pqueue | 337.166 | 1831.567 | 0.18× | 0.18–0.19 | within |
| pqueue/build-drain-ascending | 2048 | core-pqueue | 337.166 | 79.815 | 4.22× | 4.21–4.24 | slower |
| bst/build-find-ascending | 2048 | core-immut-sorted-set | 968.976 | 1201.616 | 0.81× | 0.77–0.84 | within |
| tree/inorder-to-array-balanced | 2048 | core-immut-sorted-set | 47.553 | 14.017 | 3.39× | 3.37–3.41 | slower |
| tree/inorder-to-array-left-skewed | 2048 | core-immut-sorted-set | 44.085 | 14.021 | 3.14× | 3.14–3.15 | slower |
| tree/to-array-balanced | 2048 | core-immut-sorted-set | 15.117 | 14.061 | 1.08× | 1.06–1.09 | slower |
| tree/to-array-left-skewed | 2048 | core-immut-sorted-set | 25.471 | 14.020 | 1.82× | 1.81–1.83 | slower |

`within` means both paired ratios are ≤ 1; `slower` means both are > 1; otherwise `inconclusive`.

## wasm-gc — final measurements

Recorded: 2026-09-15T01:58:42.895Z. Target: wasm-gc, release.
CPU: Apple M5. OS: darwin 25.6.0 (arm64).
Node: v24.21.0. Repository base: 4085aae7f252d0e52a8cec98763d423ce6abd611 (working tree dirty: true).
Moon: moon 0.1.20260904 (94521db 2026-09-04) ~/.moon/bin/moon moonc v0.10.12+1634b282e (2026-09-07) ~/.moon/bin/moonc moonrun 0.1.20260904 (94521db 2026-09-04) ~/.moon/bin/moonrun  Feature flags enabled: rr_moon_mod,rr_moon_pkg.
Installed core source SHA-256: 03e2587990f077d1d1c9ca5701bdc0d28f0bd458571af0f2954af826bbe412f5.
Runtime source SHA-256: 96dc57055f2b0ece94872251c617bc07a7e4414108a6d2b4a085009ad01acbe1.
Benchmark source SHA-256: 88be7d2c789dfe09f8f347514977c4d1df471c121234fca94bb97504778f3958.

Times are microseconds per complete workload: the mean of two batch medians.
Each pass contains five calibrated batches; implementation order is reversed in pass 2.
Ratios are veri/core (above 1 means slower). The range shows the two paired ratios, not a confidence interval.
These measurements compare the current data structures, including representation and allocation costs; they do not isolate proof-contract overhead.

| Workload | n | Core baseline | veri µs | core µs | Ratio | Paired range | Compared with 1.0 |
| --- | ---: | --- | ---: | ---: | ---: | ---: | --- |
| list/reverse-to-array | 256 | core-list | 0.646 | 1.175 | 0.55× | 0.54–0.56 | within |
| list/append-to-array | 256 | core-list | 1.351 | 2.102 | 0.64× | 0.64–0.64 | within |
| list/length | 256 | core-list | 0.221 | 0.221 | 1.00× | 1.00–1.00 | slower |
| stack/build-drain | 256 | core-list | 0.911 | 0.566 | 1.61× | 1.61–1.61 | slower |
| stack/build-drain | 256 | core-array | 0.911 | 0.643 | 1.42× | 1.38–1.45 | slower |
| queue/build-drain | 256 | core-queue | 1.799 | 2.791 | 0.64× | 0.64–0.64 | within |
| queue/repeated-peek | 256 | core-queue | 0.131 | 0.140 | 0.94× | 0.93–0.94 | within |
| pqueue/build-drain-shuffled | 256 | core-immut-pqueue | 8.699 | 15.951 | 0.55× | 0.54–0.55 | within |
| pqueue/build-drain-shuffled | 256 | core-pqueue | 8.699 | 3.412 | 2.55× | 2.55–2.55 | slower |
| bst/build-find-shuffled | 256 | core-immut-sorted-set | 10.624 | 11.262 | 0.94× | 0.94–0.94 | within |
| pqueue/build-drain-ascending | 256 | core-immut-pqueue | 4.543 | 16.181 | 0.28× | 0.28–0.29 | within |
| pqueue/build-drain-ascending | 256 | core-pqueue | 4.543 | 1.422 | 3.19× | 3.18–3.21 | slower |
| bst/build-find-ascending | 256 | core-immut-sorted-set | 12.517 | 18.996 | 0.66× | 0.65–0.66 | within |
| tree/inorder-to-array-balanced | 256 | core-immut-sorted-set | 0.831 | 0.653 | 1.27× | 1.27–1.27 | slower |
| tree/inorder-to-array-left-skewed | 256 | core-immut-sorted-set | 0.953 | 0.631 | 1.51× | 1.49–1.53 | slower |
| tree/to-array-balanced | 256 | core-immut-sorted-set | 0.637 | 0.656 | 0.97× | 0.97–0.97 | within |
| tree/to-array-left-skewed | 256 | core-immut-sorted-set | 1.485 | 0.641 | 2.32× | 2.28–2.35 | slower |
| list/reverse-to-array | 2048 | core-list | 5.991 | 9.373 | 0.64× | 0.64–0.64 | within |
| list/append-to-array | 2048 | core-list | 13.011 | 15.789 | 0.82× | 0.79–0.86 | within |
| list/length | 2048 | core-list | 1.787 | 2.693 | 0.66× | 0.66–0.67 | within |
| stack/build-drain | 2048 | core-list | 7.714 | 4.587 | 1.68× | 1.68–1.68 | slower |
| stack/build-drain | 2048 | core-array | 7.714 | 4.516 | 1.71× | 1.69–1.73 | slower |
| queue/build-drain | 2048 | core-queue | 13.910 | 24.998 | 0.56× | 0.54–0.57 | within |
| queue/repeated-peek | 2048 | core-queue | 0.964 | 0.965 | 1.00× | 1.00–1.00 | inconclusive |
| pqueue/build-drain-shuffled | 2048 | core-immut-pqueue | 105.982 | 194.815 | 0.54× | 0.54–0.55 | within |
| pqueue/build-drain-shuffled | 2048 | core-pqueue | 105.982 | 42.007 | 2.52× | 2.52–2.53 | slower |
| bst/build-find-shuffled | 2048 | core-immut-sorted-set | 124.174 | 131.911 | 0.94× | 0.94–0.94 | within |
| pqueue/build-drain-ascending | 2048 | core-immut-pqueue | 37.815 | 189.397 | 0.20× | 0.20–0.20 | within |
| pqueue/build-drain-ascending | 2048 | core-pqueue | 37.815 | 11.057 | 3.42× | 3.41–3.43 | slower |
| bst/build-find-ascending | 2048 | core-immut-sorted-set | 184.640 | 220.668 | 0.84× | 0.81–0.86 | within |
| tree/inorder-to-array-balanced | 2048 | core-immut-sorted-set | 7.184 | 4.851 | 1.48× | 1.46–1.50 | slower |
| tree/inorder-to-array-left-skewed | 2048 | core-immut-sorted-set | 7.406 | 4.828 | 1.53× | 1.53–1.54 | slower |
| tree/to-array-balanced | 2048 | core-immut-sorted-set | 4.704 | 4.784 | 0.98× | 0.98–0.99 | within |
| tree/to-array-left-skewed | 2048 | core-immut-sorted-set | 11.643 | 4.790 | 2.43× | 2.42–2.44 | slower |

`within` means both paired ratios are ≤ 1; `slower` means both are > 1; otherwise `inconclusive`.
