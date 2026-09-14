# コレクション性能 / Collection performance

2026-09-14、Apple M5 で記録した最適化後の release 測定。旧版の全測定は [BEFORE.md](BEFORE.md) に保存した。優先キューを skew heap、探索木を赤黒木に変更し、Queue の正規化・木の線形走査・ラッパー表現も改善した。

Release measurements after optimization, recorded on 2026-09-14 on Apple M5. [BEFORE.md](BEFORE.md) preserves all original measurements. The new implementations use a skew heap, a red-black search tree, normalized queues, linear inorder traversal, and value-type wrappers.

**全バックエンド・全処理で core 以下という条件は未達。** Proof 専用コードの実行コストではなく、実装・API・表現・確保を含む比較である。

**The universal no-slowdown target is not met.** These compare implementations, APIs, representations, and allocations; they do not isolate proof-contract overhead.

比率は veri/core（1未満が速く、1は同等）。12処理×2サイズ、各バックエンド30比較・108測定サマリー。順序を逆転した2回の測定で、各回は自動調整した5バッチ。すべての計測サイズとバックエンドで出力の一致を計測前に検査した。

Ratios are veri/core (<1 is faster; 1 is equal time). Twelve workloads at two sizes give 30 comparisons and 108 summaries per backend. Each comparison reverses implementation order over two passes, with five calibrated batches each. Exact output checks precede timing on every measured size and backend.

Queue の連続 peek は同じ構造を読み続けるため、コンパイラがループ外へ読み取りを移す場合がある。個々の呼び出しの遅延比ではない。汎用二分木の比較は同じ整列済みの値の列挙で、任意形状の木に対応する core 型との比較ではない。可変の core 実装には永続スナップショットのコピーを加えない。

Repeated queue peeks may be hoisted by the compiler; their ratios are not per-call latency ratios. Generic-tree workloads compare enumeration of the same ordered values, not equivalent arbitrary-shape tree APIs. Mutable core baselines incur no simulated snapshot copying.

比較条件 / Boundaries: [日本語 README](../../README.ja.md#コレクションのベンチマーク), [English README](../../README.md#collection-benchmarks).

| Backend | Both orders ≤ 1.0 | Both orders > 1.0 | Straddles 1.0 |
| --- | ---: | ---: | ---: |
| native | 9 | 19 | 2 |
| js | 10 | 13 | 7 |
| wasm | 13 | 16 | 1 |
| wasm-gc | 13 | 13 | 4 |

## 2,048 要素での変更前 → 変更後 / Before → after at n=2048

比率の変化（veri/core）。別の時点の測定なので、core の時間も変動する。各測定の実時間と順序による幅は下表と旧版を参照。

Changes in veri/core ratios. The runs occurred at different times, so core timings also vary; use the complete tables for absolute times and paired ranges.

| Workload | Core baseline | native | js | wasm | wasm-gc |
| --- | --- | ---: | ---: | ---: | ---: |
| list/reverse-to-array | core-list | 0.86 → 0.91 | 0.67 → 0.49 | 1.10 → 0.26 | 0.61 → 0.62 |
| list/append-to-array | core-list | 1.27 → 1.21 | 1.26 → 1.29 | 0.94 → 0.91 | 0.78 → 1.26 |
| list/length | core-list | 0.72 → 1.00 | 4.75 → 0.62 | 1.47 → 0.98 | 2.22 → 0.67 |
| stack/build-drain | core-list | 5.08 → 1.73 | 1.58 → 1.14 | 4.56 → 1.83 | 2.72 → 1.49 |
| stack/build-drain | core-array | 19.72 → 7.83 | 0.83 → 0.66 | 9.88 → 3.84 | 3.00 → 1.50 |
| queue/build-drain | core-queue | 8.07 → 6.61 | 1.15 → 0.66 | 9.61 → 6.53 | 0.65 → 0.63 |
| queue/repeated-peek | core-queue | 2808047.99 → 78.68 | 4530.19 → 0.72 | 41766.20 → 0.66 | 7191.67 → 1.08 |
| pqueue/build-drain-shuffled | core-immut-pqueue | 15.06 → 0.43 | 18.04 → 0.53 | 12.86 → 0.38 | 13.32 → 0.53 |
| pqueue/build-drain-shuffled | core-pqueue | 132.42 → 3.81 | 120.80 → 5.31 | 129.98 → 4.13 | 54.68 → 2.50 |
| bst/build-find-shuffled | core-immut-sorted-set | 0.90 → 1.07 | 0.65 → 1.81 | 0.95 → 1.03 | 0.58 → 0.94 |
| pqueue/build-drain-ascending | core-immut-pqueue | 32.32 → 0.48 | 48.23 → 1.12 | 25.26 → 0.48 | 28.13 → 0.59 |
| pqueue/build-drain-ascending | core-pqueue | 872.04 → 13.16 | 906.57 → 29.74 | 527.48 → 10.41 | 611.71 → 10.04 |
| bst/build-find-ascending | core-immut-sorted-set | 62.58 → 0.83 | 52.84 → 1.23 | 42.42 → 0.74 | 39.07 → 0.80 |
| tree/inorder-to-array-balanced | core-immut-sorted-set | 22.84 → 3.88 | 4.92 → 0.72 | 17.57 → 4.23 | 6.24 → 1.48 |
| tree/inorder-to-array-left-skewed | core-immut-sorted-set | 5021.09 → 3.65 | 1189.34 → 1.12 | 2673.28 → 4.03 | 1486.09 → 1.56 |

再測定 / Rerun:

```sh
just bench-backends
just bench-check native 1.0
```

今回の native ログに上限1.0を適用すると、30比較中21比較が条件を満たさず終了コード2となった。

Applying a limit of 1.0 to this native log returned exit code 2: 21 of 30 comparisons did not establish non-regression.

`bench-check` は片方の測定順でも上限を超えれば終了コード2となる。判定保留も失敗として扱う。測定結果の欠落や計測自体の失敗は別のエラーとなる。

`bench-check` exits 2 when either measurement order exceeds the limit, including inconclusive comparisons. Missing measurements and failed benchmark processes are separate errors. Fresh raw logs and full-precision JSON are written to `_build/benchmarks/`.

## native

Recorded: 2026-09-14T14:34:30.455Z. Target: native, release.
CPU: Apple M5. OS: darwin 25.6.0 (arm64).
Node: v24.21.0. Repository base: 5b3d16a9e13dd77bca066c6fa63178e413a568cc (working tree dirty: true).
Moon: moon 0.1.20260904 (94521db 2026-09-04) ~/.moon/bin/moon moonc v0.10.12+1634b282e (2026-09-07) ~/.moon/bin/moonc moonrun 0.1.20260904 (94521db 2026-09-04) ~/.moon/bin/moonrun  Feature flags enabled: rr_moon_mod,rr_moon_pkg.
Installed core source SHA-256: 03e2587990f077d1d1c9ca5701bdc0d28f0bd458571af0f2954af826bbe412f5.
Runtime source SHA-256: f85bb12622a48b82b463c0f8213acceca105a852c4e5a045831c1f5f5b42fa01.
Benchmark source SHA-256: 5021b923fc43502390e3e698f34b03b3af0f5a16461eff31635005169f5e4504.

Times are microseconds per complete workload: the mean of two batch medians.
Each pass contains five calibrated batches; implementation order is reversed in pass 2.
Ratios are veri/core (above 1 means slower). The range shows the two paired ratios, not a confidence interval.
These measurements compare the current data structures, including representation and allocation costs; they do not isolate proof-contract overhead.

| Workload | n | Core baseline | veri µs | core µs | Ratio | Paired range | Compared with 1.0 |
| --- | ---: | --- | ---: | ---: | ---: | ---: | --- |
| list/reverse-to-array | 256 | core-list | 1.744 | 2.014 | 0.87× | 0.86–0.88 | within |
| list/append-to-array | 256 | core-list | 3.486 | 2.764 | 1.26× | 1.20–1.31 | slower |
| list/length | 256 | core-list | 0.348 | 0.361 | 0.97× | 0.96–0.97 | within |
| stack/build-drain | 256 | core-list | 2.043 | 1.248 | 1.64× | 1.44–1.89 | slower |
| stack/build-drain | 256 | core-array | 2.043 | 0.451 | 4.53× | 4.00–5.19 | slower |
| queue/build-drain | 256 | core-queue | 4.761 | 1.301 | 3.66× | 3.26–4.19 | slower |
| queue/repeated-peek | 256 | core-queue | 0.117 | 0.010 | 12.09× | 11.98–12.20 | slower |
| pqueue/build-drain-shuffled | 256 | core-immut-pqueue | 26.761 | 56.128 | 0.48× | 0.47–0.49 | within |
| pqueue/build-drain-shuffled | 256 | core-pqueue | 26.761 | 7.298 | 3.67× | 3.65–3.68 | slower |
| bst/build-find-shuffled | 256 | core-immut-sorted-set | 33.270 | 37.003 | 0.90× | 0.81–1.01 | inconclusive |
| pqueue/build-drain-ascending | 256 | core-immut-pqueue | 29.116 | 55.148 | 0.53× | 0.51–0.54 | within |
| pqueue/build-drain-ascending | 256 | core-pqueue | 29.116 | 3.463 | 8.41× | 8.22–8.60 | slower |
| bst/build-find-ascending | 256 | core-immut-sorted-set | 42.488 | 44.335 | 0.96× | 0.95–0.97 | within |
| tree/inorder-to-array-balanced | 256 | core-immut-sorted-set | 2.367 | 0.651 | 3.64× | 3.54–3.74 | slower |
| tree/inorder-to-array-left-skewed | 256 | core-immut-sorted-set | 2.286 | 0.652 | 3.50× | 3.40–3.61 | slower |
| list/reverse-to-array | 2048 | core-list | 15.135 | 16.691 | 0.91× | 0.90–0.91 | within |
| list/append-to-array | 2048 | core-list | 26.744 | 22.040 | 1.21× | 1.21–1.22 | slower |
| list/length | 2048 | core-list | 2.524 | 2.536 | 1.00× | 0.96–1.03 | inconclusive |
| stack/build-drain | 2048 | core-list | 15.015 | 8.694 | 1.73× | 1.67–1.79 | slower |
| stack/build-drain | 2048 | core-array | 15.015 | 1.919 | 7.83× | 7.67–7.99 | slower |
| queue/build-drain | 2048 | core-queue | 51.537 | 7.794 | 6.61× | 5.53–7.55 | slower |
| queue/repeated-peek | 2048 | core-queue | 0.773 | 0.010 | 78.68× | 64.21–91.81 | slower |
| pqueue/build-drain-shuffled | 2048 | core-immut-pqueue | 353.924 | 820.092 | 0.43× | 0.42–0.44 | within |
| pqueue/build-drain-shuffled | 2048 | core-pqueue | 353.924 | 93.011 | 3.81× | 3.74–3.87 | slower |
| bst/build-find-shuffled | 2048 | core-immut-sorted-set | 442.986 | 414.633 | 1.07× | 1.06–1.08 | slower |
| pqueue/build-drain-ascending | 2048 | core-immut-pqueue | 368.128 | 762.599 | 0.48× | 0.46–0.50 | within |
| pqueue/build-drain-ascending | 2048 | core-pqueue | 368.128 | 27.964 | 13.16× | 12.88–13.45 | slower |
| bst/build-find-ascending | 2048 | core-immut-sorted-set | 453.789 | 544.964 | 0.83× | 0.82–0.84 | within |
| tree/inorder-to-array-balanced | 2048 | core-immut-sorted-set | 19.798 | 5.096 | 3.88× | 3.84–3.94 | slower |
| tree/inorder-to-array-left-skewed | 2048 | core-immut-sorted-set | 18.419 | 5.045 | 3.65× | 3.62–3.68 | slower |

`within` means both paired ratios are ≤ 1; `slower` means both are > 1; otherwise `inconclusive`.

## js

Recorded: 2026-09-14T14:35:52.502Z. Target: js, release.
CPU: Apple M5. OS: darwin 25.6.0 (arm64).
Node: v24.21.0. Repository base: 5b3d16a9e13dd77bca066c6fa63178e413a568cc (working tree dirty: true).
Moon: moon 0.1.20260904 (94521db 2026-09-04) ~/.moon/bin/moon moonc v0.10.12+1634b282e (2026-09-07) ~/.moon/bin/moonc moonrun 0.1.20260904 (94521db 2026-09-04) ~/.moon/bin/moonrun  Feature flags enabled: rr_moon_mod,rr_moon_pkg.
Installed core source SHA-256: 03e2587990f077d1d1c9ca5701bdc0d28f0bd458571af0f2954af826bbe412f5.
Runtime source SHA-256: f85bb12622a48b82b463c0f8213acceca105a852c4e5a045831c1f5f5b42fa01.
Benchmark source SHA-256: 5021b923fc43502390e3e698f34b03b3af0f5a16461eff31635005169f5e4504.

Times are microseconds per complete workload: the mean of two batch medians.
Each pass contains five calibrated batches; implementation order is reversed in pass 2.
Ratios are veri/core (above 1 means slower). The range shows the two paired ratios, not a confidence interval.
These measurements compare the current data structures, including representation and allocation costs; they do not isolate proof-contract overhead.

| Workload | n | Core baseline | veri µs | core µs | Ratio | Paired range | Compared with 1.0 |
| --- | ---: | --- | ---: | ---: | ---: | ---: | --- |
| list/reverse-to-array | 256 | core-list | 1.192 | 1.834 | 0.65× | 0.43–0.87 | within |
| list/append-to-array | 256 | core-list | 5.249 | 3.454 | 1.52× | 1.30–1.74 | slower |
| list/length | 256 | core-list | 0.224 | 0.219 | 1.02× | 0.98–1.06 | inconclusive |
| stack/build-drain | 256 | core-list | 1.958 | 1.616 | 1.21× | 1.20–1.23 | slower |
| stack/build-drain | 256 | core-array | 1.958 | 2.692 | 0.73× | 0.71–0.74 | within |
| queue/build-drain | 256 | core-queue | 3.117 | 2.515 | 1.24× | 1.23–1.25 | slower |
| queue/repeated-peek | 256 | core-queue | 0.055 | 0.245 | 0.22× | 0.22–0.24 | within |
| pqueue/build-drain-shuffled | 256 | core-immut-pqueue | 13.880 | 31.777 | 0.44× | 0.43–0.44 | within |
| pqueue/build-drain-shuffled | 256 | core-pqueue | 13.880 | 4.751 | 2.92× | 2.78–3.07 | slower |
| bst/build-find-shuffled | 256 | core-immut-sorted-set | 23.255 | 19.797 | 1.17× | 1.12–1.23 | slower |
| pqueue/build-drain-ascending | 256 | core-immut-pqueue | 16.515 | 30.834 | 0.54× | 0.53–0.54 | within |
| pqueue/build-drain-ascending | 256 | core-pqueue | 16.515 | 2.427 | 6.81× | 6.61–7.00 | slower |
| bst/build-find-ascending | 256 | core-immut-sorted-set | 32.941 | 33.702 | 0.98× | 0.96–0.99 | within |
| tree/inorder-to-array-balanced | 256 | core-immut-sorted-set | 2.218 | 1.871 | 1.19× | 1.18–1.19 | slower |
| tree/inorder-to-array-left-skewed | 256 | core-immut-sorted-set | 2.161 | 1.829 | 1.18× | 1.18–1.19 | slower |
| list/reverse-to-array | 2048 | core-list | 11.154 | 22.785 | 0.49× | 0.31–0.73 | within |
| list/append-to-array | 2048 | core-list | 36.577 | 28.426 | 1.29× | 1.28–1.29 | slower |
| list/length | 2048 | core-list | 1.692 | 2.724 | 0.62× | 0.60–0.65 | within |
| stack/build-drain | 2048 | core-list | 15.893 | 13.963 | 1.14× | 1.12–1.16 | slower |
| stack/build-drain | 2048 | core-array | 15.893 | 24.075 | 0.66× | 0.66–0.66 | within |
| queue/build-drain | 2048 | core-queue | 27.947 | 42.468 | 0.66× | 0.46–1.23 | inconclusive |
| queue/repeated-peek | 2048 | core-queue | 1.670 | 2.316 | 0.72× | 0.38–1.09 | inconclusive |
| pqueue/build-drain-shuffled | 2048 | core-immut-pqueue | 821.003 | 1543.256 | 0.53× | 0.49–0.55 | within |
| pqueue/build-drain-shuffled | 2048 | core-pqueue | 821.003 | 154.549 | 5.31× | 4.79–6.73 | slower |
| bst/build-find-shuffled | 2048 | core-immut-sorted-set | 1013.816 | 558.784 | 1.81× | 0.43–4.87 | inconclusive |
| pqueue/build-drain-ascending | 2048 | core-immut-pqueue | 841.231 | 753.844 | 1.12× | 0.80–1.83 | inconclusive |
| pqueue/build-drain-ascending | 2048 | core-pqueue | 841.231 | 28.282 | 29.74× | 24.33–37.92 | slower |
| bst/build-find-ascending | 2048 | core-immut-sorted-set | 993.106 | 805.434 | 1.23× | 0.98–1.80 | inconclusive |
| tree/inorder-to-array-balanced | 2048 | core-immut-sorted-set | 30.372 | 42.201 | 0.72× | 0.61–1.11 | inconclusive |
| tree/inorder-to-array-left-skewed | 2048 | core-immut-sorted-set | 19.214 | 17.202 | 1.12× | 1.11–1.12 | slower |

`within` means both paired ratios are ≤ 1; `slower` means both are > 1; otherwise `inconclusive`.

## wasm

Recorded: 2026-09-14T14:37:23.949Z. Target: wasm, release.
CPU: Apple M5. OS: darwin 25.6.0 (arm64).
Node: v24.21.0. Repository base: 5b3d16a9e13dd77bca066c6fa63178e413a568cc (working tree dirty: true).
Moon: moon 0.1.20260904 (94521db 2026-09-04) ~/.moon/bin/moon moonc v0.10.12+1634b282e (2026-09-07) ~/.moon/bin/moonc moonrun 0.1.20260904 (94521db 2026-09-04) ~/.moon/bin/moonrun  Feature flags enabled: rr_moon_mod,rr_moon_pkg.
Installed core source SHA-256: 03e2587990f077d1d1c9ca5701bdc0d28f0bd458571af0f2954af826bbe412f5.
Runtime source SHA-256: f85bb12622a48b82b463c0f8213acceca105a852c4e5a045831c1f5f5b42fa01.
Benchmark source SHA-256: 5021b923fc43502390e3e698f34b03b3af0f5a16461eff31635005169f5e4504.

Times are microseconds per complete workload: the mean of two batch medians.
Each pass contains five calibrated batches; implementation order is reversed in pass 2.
Ratios are veri/core (above 1 means slower). The range shows the two paired ratios, not a confidence interval.
These measurements compare the current data structures, including representation and allocation costs; they do not isolate proof-contract overhead.

| Workload | n | Core baseline | veri µs | core µs | Ratio | Paired range | Compared with 1.0 |
| --- | ---: | --- | ---: | ---: | ---: | ---: | --- |
| list/reverse-to-array | 256 | core-list | 7.274 | 8.173 | 0.89× | 0.89–0.89 | within |
| list/append-to-array | 256 | core-list | 8.562 | 9.700 | 0.88× | 0.86–0.90 | within |
| list/length | 256 | core-list | 0.537 | 0.529 | 1.01× | 1.01–1.02 | slower |
| stack/build-drain | 256 | core-list | 9.683 | 5.431 | 1.78× | 1.77–1.80 | slower |
| stack/build-drain | 256 | core-array | 9.683 | 2.483 | 3.90× | 3.73–4.08 | slower |
| queue/build-drain | 256 | core-queue | 18.101 | 2.920 | 6.20× | 6.16–6.24 | slower |
| queue/repeated-peek | 256 | core-queue | 0.230 | 0.313 | 0.74× | 0.73–0.74 | within |
| pqueue/build-drain-shuffled | 256 | core-immut-pqueue | 67.564 | 161.197 | 0.42× | 0.41–0.43 | within |
| pqueue/build-drain-shuffled | 256 | core-pqueue | 67.564 | 17.259 | 3.91× | 3.82–4.01 | slower |
| bst/build-find-shuffled | 256 | core-immut-sorted-set | 68.168 | 63.574 | 1.07× | 1.07–1.07 | slower |
| pqueue/build-drain-ascending | 256 | core-immut-pqueue | 70.820 | 159.903 | 0.44× | 0.42–0.47 | within |
| pqueue/build-drain-ascending | 256 | core-pqueue | 70.820 | 10.202 | 6.94× | 6.76–7.11 | slower |
| bst/build-find-ascending | 256 | core-immut-sorted-set | 91.628 | 99.995 | 0.92× | 0.89–0.94 | within |
| tree/inorder-to-array-balanced | 256 | core-immut-sorted-set | 7.775 | 2.085 | 3.73× | 3.72–3.74 | slower |
| tree/inorder-to-array-left-skewed | 256 | core-immut-sorted-set | 9.226 | 2.164 | 4.26× | 3.57–4.98 | slower |
| list/reverse-to-array | 2048 | core-list | 60.767 | 237.754 | 0.26× | 0.25–0.27 | within |
| list/append-to-array | 2048 | core-list | 67.988 | 75.016 | 0.91× | 0.90–0.92 | within |
| list/length | 2048 | core-list | 3.910 | 3.985 | 0.98× | 0.97–0.99 | within |
| stack/build-drain | 2048 | core-list | 75.953 | 41.395 | 1.83× | 1.74–1.93 | slower |
| stack/build-drain | 2048 | core-array | 75.953 | 19.779 | 3.84× | 3.63–4.06 | slower |
| queue/build-drain | 2048 | core-queue | 134.866 | 20.662 | 6.53× | 6.35–6.71 | slower |
| queue/repeated-peek | 2048 | core-queue | 1.557 | 2.345 | 0.66× | 0.65–0.68 | within |
| pqueue/build-drain-shuffled | 2048 | core-immut-pqueue | 779.600 | 2030.347 | 0.38× | 0.36–0.41 | within |
| pqueue/build-drain-shuffled | 2048 | core-pqueue | 779.600 | 188.818 | 4.13× | 4.05–4.20 | slower |
| bst/build-find-shuffled | 2048 | core-immut-sorted-set | 959.957 | 930.758 | 1.03× | 0.96–1.12 | inconclusive |
| pqueue/build-drain-ascending | 2048 | core-immut-pqueue | 927.535 | 1924.486 | 0.48× | 0.43–0.53 | within |
| pqueue/build-drain-ascending | 2048 | core-pqueue | 927.535 | 89.108 | 10.41× | 8.91–12.18 | slower |
| bst/build-find-ascending | 2048 | core-immut-sorted-set | 988.742 | 1338.201 | 0.74× | 0.70–0.78 | within |
| tree/inorder-to-array-balanced | 2048 | core-immut-sorted-set | 67.279 | 15.901 | 4.23× | 4.01–4.43 | slower |
| tree/inorder-to-array-left-skewed | 2048 | core-immut-sorted-set | 67.128 | 16.665 | 4.03× | 3.44–4.64 | slower |

`within` means both paired ratios are ≤ 1; `slower` means both are > 1; otherwise `inconclusive`.

## wasm-gc

Recorded: 2026-09-14T14:38:47.893Z. Target: wasm-gc, release.
CPU: Apple M5. OS: darwin 25.6.0 (arm64).
Node: v24.21.0. Repository base: 5b3d16a9e13dd77bca066c6fa63178e413a568cc (working tree dirty: true).
Moon: moon 0.1.20260904 (94521db 2026-09-04) ~/.moon/bin/moon moonc v0.10.12+1634b282e (2026-09-07) ~/.moon/bin/moonc moonrun 0.1.20260904 (94521db 2026-09-04) ~/.moon/bin/moonrun  Feature flags enabled: rr_moon_mod,rr_moon_pkg.
Installed core source SHA-256: 03e2587990f077d1d1c9ca5701bdc0d28f0bd458571af0f2954af826bbe412f5.
Runtime source SHA-256: f85bb12622a48b82b463c0f8213acceca105a852c4e5a045831c1f5f5b42fa01.
Benchmark source SHA-256: 5021b923fc43502390e3e698f34b03b3af0f5a16461eff31635005169f5e4504.

Times are microseconds per complete workload: the mean of two batch medians.
Each pass contains five calibrated batches; implementation order is reversed in pass 2.
Ratios are veri/core (above 1 means slower). The range shows the two paired ratios, not a confidence interval.
These measurements compare the current data structures, including representation and allocation costs; they do not isolate proof-contract overhead.

| Workload | n | Core baseline | veri µs | core µs | Ratio | Paired range | Compared with 1.0 |
| --- | ---: | --- | ---: | ---: | ---: | ---: | --- |
| list/reverse-to-array | 256 | core-list | 0.787 | 1.479 | 0.53× | 0.48–0.59 | within |
| list/append-to-array | 256 | core-list | 1.531 | 2.563 | 0.60× | 0.59–0.60 | within |
| list/length | 256 | core-list | 0.282 | 0.258 | 1.09× | 1.00–1.20 | inconclusive |
| stack/build-drain | 256 | core-list | 1.270 | 0.833 | 1.52× | 1.51–1.54 | slower |
| stack/build-drain | 256 | core-array | 1.270 | 0.879 | 1.44× | 1.43–1.45 | slower |
| queue/build-drain | 256 | core-queue | 2.650 | 3.159 | 0.84× | 0.69–1.00 | inconclusive |
| queue/repeated-peek | 256 | core-queue | 0.179 | 0.168 | 1.07× | 0.98–1.14 | inconclusive |
| pqueue/build-drain-shuffled | 256 | core-immut-pqueue | 8.794 | 17.659 | 0.50× | 0.49–0.50 | within |
| pqueue/build-drain-shuffled | 256 | core-pqueue | 8.794 | 3.703 | 2.38× | 2.29–2.46 | slower |
| bst/build-find-shuffled | 256 | core-immut-sorted-set | 11.175 | 12.159 | 0.92× | 0.91–0.93 | within |
| pqueue/build-drain-ascending | 256 | core-immut-pqueue | 9.502 | 16.645 | 0.57× | 0.57–0.57 | within |
| pqueue/build-drain-ascending | 256 | core-pqueue | 9.502 | 1.481 | 6.42× | 6.32–6.51 | slower |
| bst/build-find-ascending | 256 | core-immut-sorted-set | 13.412 | 20.342 | 0.66× | 0.65–0.66 | within |
| tree/inorder-to-array-balanced | 256 | core-immut-sorted-set | 0.872 | 0.658 | 1.33× | 1.32–1.33 | slower |
| tree/inorder-to-array-left-skewed | 256 | core-immut-sorted-set | 0.988 | 0.658 | 1.50× | 1.50–1.50 | slower |
| list/reverse-to-array | 2048 | core-list | 6.013 | 9.740 | 0.62× | 0.61–0.62 | within |
| list/append-to-array | 2048 | core-list | 20.462 | 16.240 | 1.26× | 0.81–1.74 | inconclusive |
| list/length | 2048 | core-list | 1.831 | 2.743 | 0.67× | 0.65–0.68 | within |
| stack/build-drain | 2048 | core-list | 7.665 | 5.151 | 1.49× | 1.47–1.51 | slower |
| stack/build-drain | 2048 | core-array | 7.665 | 5.113 | 1.50× | 1.47–1.53 | slower |
| queue/build-drain | 2048 | core-queue | 15.090 | 23.984 | 0.63× | 0.61–0.65 | within |
| queue/repeated-peek | 2048 | core-queue | 1.138 | 1.057 | 1.08× | 1.05–1.10 | slower |
| pqueue/build-drain-shuffled | 2048 | core-immut-pqueue | 106.397 | 200.741 | 0.53× | 0.52–0.54 | within |
| pqueue/build-drain-shuffled | 2048 | core-pqueue | 106.397 | 42.620 | 2.50× | 2.47–2.52 | slower |
| bst/build-find-shuffled | 2048 | core-immut-sorted-set | 130.076 | 138.373 | 0.94× | 0.92–0.96 | within |
| pqueue/build-drain-ascending | 2048 | core-immut-pqueue | 116.973 | 196.787 | 0.59× | 0.59–0.60 | within |
| pqueue/build-drain-ascending | 2048 | core-pqueue | 116.973 | 11.648 | 10.04× | 10.03–10.05 | slower |
| bst/build-find-ascending | 2048 | core-immut-sorted-set | 177.568 | 222.190 | 0.80× | 0.80–0.80 | within |
| tree/inorder-to-array-balanced | 2048 | core-immut-sorted-set | 7.520 | 5.068 | 1.48× | 1.46–1.50 | slower |
| tree/inorder-to-array-left-skewed | 2048 | core-immut-sorted-set | 7.938 | 5.077 | 1.56× | 1.53–1.60 | slower |

`within` means both paired ratios are ≤ 1; `slower` means both are > 1; otherwise `inconclusive`.
