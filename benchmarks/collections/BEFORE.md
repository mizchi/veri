# 最適化前のコレクション性能 / Collection performance before optimization

2026-09-14、Apple M5 で記録した release ビルドの測定結果。最適化前の実装は、core と比べて遅い処理があり、「一律に遅くならない」という条件を満たしていない。

Release measurements recorded on 2026-09-14 on Apple M5. The implementations before optimization have workloads slower than core and do not meet an unconditional no-slowdown target.

比率は veri/core。各組を順序を逆転して2回計測し、各回で自動調整した5バッチを測定した。256・2,048要素の出力一致を計測前に検査した。入力生成は計測外で、構築・出力を含む範囲は [ベンチマークの説明（日本語）](../../docs/benchmarks.ja.md) / [Benchmark guide (English)](../../docs/benchmarks.md) に記載する。

Ratios are veri/core. Both implementation orders are measured with five calibrated batches each; exact outputs are checked before timing at n=256 and n=2048. These are complete workloads, including the documented allocations and conversions. See the benchmark guides linked above for comparison boundaries.

Queue の連続 peek では同じキューを読み続ける。core 側の読み取りをコンパイラがループ外へ移す可能性があるため、特に大きな倍率は個々の呼び出しの遅延比としては解釈しない。二分木の比較は同じ整列済み値の列挙であり、任意形状の木に対応する core の型を比較しているわけではない。

Repeated queue peeks reuse one queue, so the compiler may hoist core reads; the very large ratios are not per-call latency ratios. Binary-tree comparisons measure enumeration of the same ordered values, not equivalent arbitrary-shape tree APIs.

| Backend | Both orders ≤ 1.0 | Both orders > 1.0 | Straddles 1.0 |
| --- | ---: | ---: | ---: |
| native | 6 | 24 | 0 |
| js | 5 | 25 | 0 |
| wasm | 4 | 25 | 1 |
| wasm-gc | 8 | 22 | 0 |

再測定 / Rerun:

```sh
just bench-backends
just bench-check native 1.0
```

`bench-check` は上限を超えた測定・判定保留で失敗する。今回の native ログを使った判定では、30組中24組が条件を満たさず終了コード2となった。

`bench-check` fails on slower or inconclusive measurements. Applying its limit of 1.0 to this native log returned exit code 2: 24 of 30 comparisons did not meet the condition.

The runtime sources for this baseline are those in commit `5b3d16a`; only the benchmark infrastructure was uncommitted. This is a dated snapshot. Fresh logs and full-precision JSON summaries are written to `_build/benchmarks/` by the commands above.

## native

Recorded: 2026-09-14T13:46:00.095Z. Target: native, release.
CPU: Apple M5. OS: darwin 25.6.0 (arm64).
Node: v24.21.0. Repository base: 5b3d16a9e13dd77bca066c6fa63178e413a568cc (working tree dirty: true).
Moon: moon 0.1.20260904 (94521db 2026-09-04) ~/.moon/bin/moon moonc v0.10.12+1634b282e (2026-09-07) ~/.moon/bin/moonc moonrun 0.1.20260904 (94521db 2026-09-04) ~/.moon/bin/moonrun  Feature flags enabled: rr_moon_mod,rr_moon_pkg.
Installed core source SHA-256: 03e2587990f077d1d1c9ca5701bdc0d28f0bd458571af0f2954af826bbe412f5.

Times are microseconds per complete workload: the mean of two batch medians.
Each pass contains five calibrated batches; implementation order is reversed in pass 2.
Ratios are veri/core (above 1 means slower). The range shows the two paired ratios, not a confidence interval.
These measurements compare the current data structures, including representation and allocation costs; they do not isolate proof-contract overhead.

| Workload | n | Core baseline | veri µs | core µs | Ratio | Paired range | Compared with 1.0 |
| --- | ---: | --- | ---: | ---: | ---: | ---: | --- |
| list/reverse-to-array | 256 | core-list | 1.700 | 1.934 | 0.88× | 0.87–0.89 | within |
| list/append-to-array | 256 | core-list | 3.170 | 2.490 | 1.27× | 1.27–1.28 | slower |
| list/length | 256 | core-list | 0.221 | 0.349 | 0.63× | 0.62–0.65 | within |
| stack/build-drain | 256 | core-list | 5.068 | 1.042 | 4.86× | 4.66–5.08 | slower |
| stack/build-drain | 256 | core-array | 5.068 | 0.375 | 13.52× | 13.09–13.97 | slower |
| queue/build-drain | 256 | core-queue | 8.157 | 1.029 | 7.93× | 6.79–9.07 | slower |
| queue/repeated-peek | 256 | core-queue | 337.668 | 0.008 | 40080.27× | 39112.66–41115.79 | slower |
| pqueue/build-drain-shuffled | 256 | core-immut-pqueue | 167.641 | 54.480 | 3.08× | 3.07–3.08 | slower |
| pqueue/build-drain-shuffled | 256 | core-pqueue | 167.641 | 6.913 | 24.25× | 23.91–24.61 | slower |
| bst/build-find-shuffled | 256 | core-immut-sorted-set | 30.634 | 33.399 | 0.92× | 0.92–0.92 | within |
| pqueue/build-drain-ascending | 256 | core-immut-pqueue | 323.672 | 52.751 | 6.14× | 6.04–6.23 | slower |
| pqueue/build-drain-ascending | 256 | core-pqueue | 323.672 | 3.244 | 99.79× | 99.10–100.49 | slower |
| bst/build-find-ascending | 256 | core-immut-sorted-set | 396.752 | 42.631 | 9.31× | 9.20–9.41 | slower |
| tree/inorder-to-array-balanced | 256 | core-immut-sorted-set | 8.876 | 0.664 | 13.36× | 13.21–13.51 | slower |
| tree/inorder-to-array-left-skewed | 256 | core-immut-sorted-set | 339.732 | 0.695 | 488.74× | 468.77–509.51 | slower |
| list/reverse-to-array | 2048 | core-list | 14.671 | 17.000 | 0.86× | 0.84–0.89 | within |
| list/append-to-array | 2048 | core-list | 26.039 | 20.451 | 1.27× | 1.25–1.29 | slower |
| list/length | 2048 | core-list | 1.749 | 2.439 | 0.72× | 0.67–0.76 | within |
| stack/build-drain | 2048 | core-list | 41.240 | 8.120 | 5.08× | 4.94–5.21 | slower |
| stack/build-drain | 2048 | core-array | 41.240 | 2.091 | 19.72× | 19.64–19.80 | slower |
| queue/build-drain | 2048 | core-queue | 58.962 | 7.310 | 8.07× | 7.80–8.34 | slower |
| queue/repeated-peek | 2048 | core-queue | 26715.656 | 0.010 | 2808047.99× | 2781940.99–2834601.28 | slower |
| pqueue/build-drain-shuffled | 2048 | core-immut-pqueue | 11459.183 | 760.816 | 15.06× | 14.98–15.14 | slower |
| pqueue/build-drain-shuffled | 2048 | core-pqueue | 11459.183 | 86.536 | 132.42× | 132.31–132.54 | slower |
| bst/build-find-shuffled | 2048 | core-immut-sorted-set | 371.798 | 413.816 | 0.90× | 0.87–0.92 | within |
| pqueue/build-drain-ascending | 2048 | core-immut-pqueue | 24558.364 | 759.956 | 32.32× | 32.26–32.38 | slower |
| pqueue/build-drain-ascending | 2048 | core-pqueue | 24558.364 | 28.162 | 872.04× | 845.06–902.73 | slower |
| bst/build-find-ascending | 2048 | core-immut-sorted-set | 29366.031 | 469.279 | 62.58× | 62.24–62.91 | slower |
| tree/inorder-to-array-balanced | 2048 | core-immut-sorted-set | 106.988 | 4.683 | 22.84× | 21.89–23.86 | slower |
| tree/inorder-to-array-left-skewed | 2048 | core-immut-sorted-set | 22858.017 | 4.552 | 5021.09× | 4975.96–5066.08 | slower |

`within` means both paired ratios are ≤ 1; `slower` means both are > 1; otherwise `inconclusive`.

## js

Recorded: 2026-09-14T13:47:23.459Z. Target: js, release.
CPU: Apple M5. OS: darwin 25.6.0 (arm64).
Node: v24.21.0. Repository base: 5b3d16a9e13dd77bca066c6fa63178e413a568cc (working tree dirty: true).
Moon: moon 0.1.20260904 (94521db 2026-09-04) ~/.moon/bin/moon moonc v0.10.12+1634b282e (2026-09-07) ~/.moon/bin/moonc moonrun 0.1.20260904 (94521db 2026-09-04) ~/.moon/bin/moonrun  Feature flags enabled: rr_moon_mod,rr_moon_pkg.
Installed core source SHA-256: 03e2587990f077d1d1c9ca5701bdc0d28f0bd458571af0f2954af826bbe412f5.

Times are microseconds per complete workload: the mean of two batch medians.
Each pass contains five calibrated batches; implementation order is reversed in pass 2.
Ratios are veri/core (above 1 means slower). The range shows the two paired ratios, not a confidence interval.
These measurements compare the current data structures, including representation and allocation costs; they do not isolate proof-contract overhead.

| Workload | n | Core baseline | veri µs | core µs | Ratio | Paired range | Compared with 1.0 |
| --- | ---: | --- | ---: | ---: | ---: | ---: | --- |
| list/reverse-to-array | 256 | core-list | 1.085 | 1.728 | 0.63× | 0.41–0.86 | within |
| list/append-to-array | 256 | core-list | 4.061 | 2.905 | 1.40× | 1.39–1.41 | slower |
| list/length | 256 | core-list | 1.664 | 0.219 | 7.60× | 7.34–7.89 | slower |
| stack/build-drain | 256 | core-list | 2.479 | 1.423 | 1.74× | 1.72–1.77 | slower |
| stack/build-drain | 256 | core-array | 2.479 | 2.463 | 1.01× | 1.00–1.01 | slower |
| queue/build-drain | 256 | core-queue | 3.021 | 2.305 | 1.31× | 1.24–1.38 | slower |
| queue/repeated-peek | 256 | core-queue | 91.332 | 0.282 | 323.66× | 308.33–338.59 | slower |
| pqueue/build-drain-shuffled | 256 | core-immut-pqueue | 113.642 | 27.250 | 4.17× | 4.15–4.19 | slower |
| pqueue/build-drain-shuffled | 256 | core-pqueue | 113.642 | 4.198 | 27.07× | 27.05–27.09 | slower |
| bst/build-find-shuffled | 256 | core-immut-sorted-set | 13.438 | 18.699 | 0.72× | 0.71–0.73 | within |
| pqueue/build-drain-ascending | 256 | core-immut-pqueue | 234.641 | 28.996 | 8.09× | 8.05–8.13 | slower |
| pqueue/build-drain-ascending | 256 | core-pqueue | 234.641 | 2.192 | 107.04× | 106.25–107.84 | slower |
| bst/build-find-ascending | 256 | core-immut-sorted-set | 278.188 | 31.194 | 8.92× | 8.88–8.96 | slower |
| tree/inorder-to-array-balanced | 256 | core-immut-sorted-set | 5.936 | 1.704 | 3.48× | 3.45–3.51 | slower |
| tree/inorder-to-array-left-skewed | 256 | core-immut-sorted-set | 233.634 | 1.672 | 139.70× | 139.34–140.05 | slower |
| list/reverse-to-array | 2048 | core-list | 12.036 | 17.934 | 0.67× | 0.47–0.85 | within |
| list/append-to-array | 2048 | core-list | 36.874 | 29.217 | 1.26× | 1.14–1.39 | slower |
| list/length | 2048 | core-list | 14.609 | 3.077 | 4.75× | 4.46–5.08 | slower |
| stack/build-drain | 2048 | core-list | 20.361 | 12.855 | 1.58× | 1.58–1.59 | slower |
| stack/build-drain | 2048 | core-array | 20.361 | 24.474 | 0.83× | 0.75–0.93 | within |
| queue/build-drain | 2048 | core-queue | 21.749 | 18.971 | 1.15× | 1.14–1.15 | slower |
| queue/repeated-peek | 2048 | core-queue | 8027.708 | 1.772 | 4530.19× | 4467.43–4594.98 | slower |
| pqueue/build-drain-shuffled | 2048 | core-immut-pqueue | 7951.067 | 440.651 | 18.04× | 15.97–20.73 | slower |
| pqueue/build-drain-shuffled | 2048 | core-pqueue | 7951.067 | 65.822 | 120.80× | 99.95–152.62 | slower |
| bst/build-find-shuffled | 2048 | core-immut-sorted-set | 145.280 | 222.660 | 0.65× | 0.65–0.66 | within |
| pqueue/build-drain-ascending | 2048 | core-immut-pqueue | 16941.007 | 351.266 | 48.23× | 47.58–48.88 | slower |
| pqueue/build-drain-ascending | 2048 | core-pqueue | 16941.007 | 18.687 | 906.57× | 871.17–944.07 | slower |
| bst/build-find-ascending | 2048 | core-immut-sorted-set | 20259.947 | 383.413 | 52.84× | 52.20–53.48 | slower |
| tree/inorder-to-array-balanced | 2048 | core-immut-sorted-set | 74.387 | 15.114 | 4.92× | 4.89–4.95 | slower |
| tree/inorder-to-array-left-skewed | 2048 | core-immut-sorted-set | 17282.792 | 14.531 | 1189.34× | 1185.66–1193.06 | slower |

`within` means both paired ratios are ≤ 1; `slower` means both are > 1; otherwise `inconclusive`.

## wasm

Recorded: 2026-09-14T13:48:47.210Z. Target: wasm, release.
CPU: Apple M5. OS: darwin 25.6.0 (arm64).
Node: v24.21.0. Repository base: 5b3d16a9e13dd77bca066c6fa63178e413a568cc (working tree dirty: true).
Moon: moon 0.1.20260904 (94521db 2026-09-04) ~/.moon/bin/moon moonc v0.10.12+1634b282e (2026-09-07) ~/.moon/bin/moonc moonrun 0.1.20260904 (94521db 2026-09-04) ~/.moon/bin/moonrun  Feature flags enabled: rr_moon_mod,rr_moon_pkg.
Installed core source SHA-256: 03e2587990f077d1d1c9ca5701bdc0d28f0bd458571af0f2954af826bbe412f5.

Times are microseconds per complete workload: the mean of two batch medians.
Each pass contains five calibrated batches; implementation order is reversed in pass 2.
Ratios are veri/core (above 1 means slower). The range shows the two paired ratios, not a confidence interval.
These measurements compare the current data structures, including representation and allocation costs; they do not isolate proof-contract overhead.

| Workload | n | Core baseline | veri µs | core µs | Ratio | Paired range | Compared with 1.0 |
| --- | ---: | --- | ---: | ---: | ---: | ---: | --- |
| list/reverse-to-array | 256 | core-list | 6.589 | 7.378 | 0.89× | 0.89–0.90 | within |
| list/append-to-array | 256 | core-list | 7.821 | 9.032 | 0.87× | 0.84–0.89 | within |
| list/length | 256 | core-list | 0.613 | 0.517 | 1.18× | 1.18–1.19 | slower |
| stack/build-drain | 256 | core-list | 19.251 | 5.151 | 3.74× | 3.45–4.01 | slower |
| stack/build-drain | 256 | core-array | 19.251 | 2.211 | 8.71× | 8.06–9.33 | slower |
| queue/build-drain | 256 | core-queue | 22.722 | 2.799 | 8.12× | 8.01–8.23 | slower |
| queue/repeated-peek | 256 | core-queue | 1473.074 | 0.320 | 4606.85× | 4465.94–4752.33 | slower |
| pqueue/build-drain-shuffled | 256 | core-immut-pqueue | 439.035 | 164.642 | 2.67× | 2.64–2.69 | slower |
| pqueue/build-drain-shuffled | 256 | core-pqueue | 439.035 | 17.071 | 25.72× | 25.38–26.07 | slower |
| bst/build-find-shuffled | 256 | core-immut-sorted-set | 77.802 | 66.067 | 1.18× | 1.14–1.22 | slower |
| pqueue/build-drain-ascending | 256 | core-immut-pqueue | 773.613 | 175.546 | 4.41× | 4.18–4.64 | slower |
| pqueue/build-drain-ascending | 256 | core-pqueue | 773.613 | 11.084 | 69.80× | 65.17–74.64 | slower |
| bst/build-find-ascending | 256 | core-immut-sorted-set | 910.187 | 106.124 | 8.58× | 8.57–8.58 | slower |
| tree/inorder-to-array-balanced | 256 | core-immut-sorted-set | 25.753 | 2.185 | 11.79× | 11.78–11.80 | slower |
| tree/inorder-to-array-left-skewed | 256 | core-immut-sorted-set | 634.107 | 2.096 | 302.58× | 296.59–308.49 | slower |
| list/reverse-to-array | 2048 | core-list | 69.830 | 63.266 | 1.10× | 0.92–1.29 | inconclusive |
| list/append-to-array | 2048 | core-list | 68.225 | 72.839 | 0.94× | 0.93–0.94 | within |
| list/length | 2048 | core-list | 5.927 | 4.029 | 1.47× | 1.45–1.49 | slower |
| stack/build-drain | 2048 | core-list | 194.893 | 42.770 | 4.56× | 4.44–4.69 | slower |
| stack/build-drain | 2048 | core-array | 194.893 | 19.735 | 9.88× | 9.36–10.40 | slower |
| queue/build-drain | 2048 | core-queue | 207.054 | 21.551 | 9.61× | 9.50–9.70 | slower |
| queue/repeated-peek | 2048 | core-queue | 98381.063 | 2.356 | 41766.20× | 41052.08–42499.05 | slower |
| pqueue/build-drain-shuffled | 2048 | core-immut-pqueue | 25194.591 | 1958.494 | 12.86× | 12.68–13.04 | slower |
| pqueue/build-drain-shuffled | 2048 | core-pqueue | 25194.591 | 193.838 | 129.98× | 124.98–135.06 | slower |
| bst/build-find-shuffled | 2048 | core-immut-sorted-set | 806.974 | 847.464 | 0.95× | 0.94–0.97 | within |
| pqueue/build-drain-ascending | 2048 | core-immut-pqueue | 44010.375 | 1742.050 | 25.26× | 25.03–25.50 | slower |
| pqueue/build-drain-ascending | 2048 | core-pqueue | 44010.375 | 83.434 | 527.48× | 526.38–528.60 | slower |
| bst/build-find-ascending | 2048 | core-immut-sorted-set | 50568.989 | 1192.002 | 42.42× | 42.03–42.82 | slower |
| tree/inorder-to-array-balanced | 2048 | core-immut-sorted-set | 270.579 | 15.398 | 17.57× | 17.23–17.92 | slower |
| tree/inorder-to-array-left-skewed | 2048 | core-immut-sorted-set | 39826.188 | 14.898 | 2673.28× | 2653.85–2692.47 | slower |

`within` means both paired ratios are ≤ 1; `slower` means both are > 1; otherwise `inconclusive`.

## wasm-gc

Recorded: 2026-09-14T13:50:14.033Z. Target: wasm-gc, release.
CPU: Apple M5. OS: darwin 25.6.0 (arm64).
Node: v24.21.0. Repository base: 5b3d16a9e13dd77bca066c6fa63178e413a568cc (working tree dirty: true).
Moon: moon 0.1.20260904 (94521db 2026-09-04) ~/.moon/bin/moon moonc v0.10.12+1634b282e (2026-09-07) ~/.moon/bin/moonc moonrun 0.1.20260904 (94521db 2026-09-04) ~/.moon/bin/moonrun  Feature flags enabled: rr_moon_mod,rr_moon_pkg.
Installed core source SHA-256: 03e2587990f077d1d1c9ca5701bdc0d28f0bd458571af0f2954af826bbe412f5.

Times are microseconds per complete workload: the mean of two batch medians.
Each pass contains five calibrated batches; implementation order is reversed in pass 2.
Ratios are veri/core (above 1 means slower). The range shows the two paired ratios, not a confidence interval.
These measurements compare the current data structures, including representation and allocation costs; they do not isolate proof-contract overhead.

| Workload | n | Core baseline | veri µs | core µs | Ratio | Paired range | Compared with 1.0 |
| --- | ---: | --- | ---: | ---: | ---: | ---: | --- |
| list/reverse-to-array | 256 | core-list | 0.706 | 1.261 | 0.56× | 0.55–0.57 | within |
| list/append-to-array | 256 | core-list | 1.437 | 2.189 | 0.66× | 0.66–0.66 | within |
| list/length | 256 | core-list | 0.502 | 0.227 | 2.21× | 2.20–2.22 | slower |
| stack/build-drain | 256 | core-list | 1.733 | 0.653 | 2.65× | 2.57–2.73 | slower |
| stack/build-drain | 256 | core-array | 1.733 | 0.726 | 2.39× | 2.30–2.47 | slower |
| queue/build-drain | 256 | core-queue | 1.932 | 2.955 | 0.65× | 0.64–0.67 | within |
| queue/repeated-peek | 256 | core-queue | 90.046 | 0.163 | 551.05× | 547.92–554.28 | slower |
| pqueue/build-drain-shuffled | 256 | core-immut-pqueue | 41.754 | 19.271 | 2.17× | 2.13–2.20 | slower |
| pqueue/build-drain-shuffled | 256 | core-pqueue | 41.754 | 4.031 | 10.36× | 9.99–10.74 | slower |
| bst/build-find-shuffled | 256 | core-immut-sorted-set | 11.343 | 18.495 | 0.61× | 0.57–0.67 | within |
| pqueue/build-drain-ascending | 256 | core-immut-pqueue | 96.029 | 20.161 | 4.76× | 4.53–4.99 | slower |
| pqueue/build-drain-ascending | 256 | core-pqueue | 96.029 | 1.712 | 56.09× | 53.89–58.17 | slower |
| bst/build-find-ascending | 256 | core-immut-sorted-set | 233.017 | 23.412 | 9.95× | 9.68–10.23 | slower |
| tree/inorder-to-array-balanced | 256 | core-immut-sorted-set | 2.953 | 0.742 | 3.98× | 3.96–3.99 | slower |
| tree/inorder-to-array-left-skewed | 256 | core-immut-sorted-set | 90.101 | 0.724 | 124.41× | 120.41–128.40 | slower |
| list/reverse-to-array | 2048 | core-list | 6.549 | 10.771 | 0.61× | 0.60–0.61 | within |
| list/append-to-array | 2048 | core-list | 13.578 | 17.345 | 0.78× | 0.75–0.82 | within |
| list/length | 2048 | core-list | 5.770 | 2.597 | 2.22× | 2.21–2.24 | slower |
| stack/build-drain | 2048 | core-list | 14.588 | 5.364 | 2.72× | 2.54–2.87 | slower |
| stack/build-drain | 2048 | core-array | 14.588 | 4.870 | 3.00× | 2.57–3.42 | slower |
| queue/build-drain | 2048 | core-queue | 16.661 | 25.483 | 0.65× | 0.62–0.69 | within |
| queue/repeated-peek | 2048 | core-queue | 8590.917 | 1.195 | 7191.67× | 6076.25–8344.27 | slower |
| pqueue/build-drain-shuffled | 2048 | core-immut-pqueue | 3527.981 | 264.877 | 13.32× | 13.21–13.42 | slower |
| pqueue/build-drain-shuffled | 2048 | core-pqueue | 3527.981 | 64.520 | 54.68× | 50.09–59.55 | slower |
| bst/build-find-shuffled | 2048 | core-immut-sorted-set | 102.840 | 177.011 | 0.58× | 0.54–0.63 | within |
| pqueue/build-drain-ascending | 2048 | core-immut-pqueue | 7392.264 | 262.800 | 28.13× | 21.84–37.23 | slower |
| pqueue/build-drain-ascending | 2048 | core-pqueue | 7392.264 | 12.085 | 611.71× | 561.35–662.11 | slower |
| bst/build-find-ascending | 2048 | core-immut-sorted-set | 10768.716 | 275.625 | 39.07× | 38.08–39.95 | slower |
| tree/inorder-to-array-balanced | 2048 | core-immut-sorted-set | 37.080 | 5.938 | 6.24× | 5.87–6.60 | slower |
| tree/inorder-to-array-left-skewed | 2048 | core-immut-sorted-set | 8866.072 | 5.966 | 1486.09× | 1473.21–1498.72 | slower |

`within` means both paired ratios are ≤ 1; `slower` means both are > 1; otherwise `inconclusive`.
