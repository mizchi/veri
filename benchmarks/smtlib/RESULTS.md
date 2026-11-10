# SMT-LIB の計測結果 / SMT-LIB measurements

2026-11-10、Linux 6.18 x86_64 のクラウド VM（4 vCPU）、moonc v0.10.20+65efd5b93、Node.js v22.23.4、release ビルド。
`just bench-smtlib <target>` の出力。時間は順序を逆にした2回の測定のバッチ中央値の平均。
高速化率は 参照 / 調整後 で、1超なら調整後が速い。範囲は2回の測定順それぞれの値。

Recorded on 2026-11-10 on a Linux 6.18 x86_64 cloud VM (4 vCPUs) with moonc v0.10.20+65efd5b93
and Node.js v22.23.4, release builds, from `just bench-smtlib <target>`. Times are the mean of
the batch medians of two passes in opposite order. Speedup is reference / tuned, so values above
1 mean the tuned code is faster; the range gives both measurement orders.

**全処理・全バックエンドで速くなったわけではない。/ Not every workload is faster on every backend.**

- JavaScript では、共有のない項を文字列連結で組み立てる方が `smtlib` より 10〜14 倍速い。
  エンジンが連結結果を rope として持ち、最後に一度だけ実体化するため。
  wasm でも 770 項の小さな入力では連結の方が速い（0.73 倍）。
- JavaScript の `initial-source|states=2048` と `incremental-safety` は参照実装と同等（1.00〜1.07 倍）。
- 共有のある項では、全バックエンドで `let` による出力が 117〜1,768 倍速い。

- On JavaScript, composing an unshared term by string concatenation is 10–14× faster than
  `smtlib`: the engine keeps concatenations as ropes and materializes them once. On wasm,
  concatenation also wins for the small 770-term input (0.73×).
- On JavaScript, `initial-source|states=2048` and `incremental-safety` only match the
  reference (1.00–1.07×).
- For a term with sharing, printing with `let` is 117–1,768× faster on every backend.

## 処理 / Workloads

| Workload | Reference | Tuned |
| --- | --- | --- |
| `model_check/initial-source` | 0.2.1 の文字列連結エンコーダ / the 0.2.1 concatenating encoder | 単一バッファへの書き込み / one output buffer |
| `model_check/response-query` | 同上、公平性つき応答性の全体クエリ / same, complete fair response query | 同上、検証1回・起点の選言を1回だけ構築 / validated once, trigger disjunction built once |
| `model_check/incremental-safety` | ランナーの手順（深さごとに step と条件）/ the runner's protocol per depth | 同上 / same |
| `model_check/decode-witness` | 1文字ずつ文字列を作る字句解析と Map / per-character tokens and a map | ビューのトークンと位置による復号 / token views decoded by position |
| `smtlib/build-and-print` | 入れ子の文字列連結 / nested string concatenation | `Context` と `Script` を毎回新規作成 / a fresh `Context` and `Script` each run |
| `smtlib/print-shared` | 共有を展開した木（3^10 個の葉）/ the expanded tree, 3^10 leaves | `let` 束縛つき DAG / the DAG with `let` bindings |
| その他 / others | — | 既存の項の再構築、出力、評価、`get-value` の復号、配列の往復 / rebuilding interned terms, printing, evaluation, decoding `get-value`, array roundtrip |

参照と調整後の出力は、計測前に同じ最適化済みバックエンド上で完全一致を確認する
（`print-shared` は文面が異なるため大きさだけを確認）。文字列は最後のコード単位を読んで実体化する。

Reference and tuned outputs are compared for exact equality on the measured optimized backend
before timing (`print-shared` differs in text by design, so only sizes are checked). Every
resulting string is materialized by reading its last code unit.

## native

| Workload | Reference | Tuned | Speedup | Range |
| --- | ---: | ---: | ---: | ---: |
| `model_check/initial-source|states=256` | 203.5 µs | 56.9 µs | 3.58× | 3.37–3.79 |
| `model_check/initial-source|states=2048` | 1.94 ms | 603.2 µs | 3.22× | 2.69–3.74 |
| `model_check/response-query|depth=16` | 476.5 µs | 104.9 µs | 4.54× | 3.90–5.26 |
| `model_check/incremental-safety|depth=16` | 78.2 µs | 62.2 µs | 1.26× | 1.12–1.46 |
| `model_check/response-query|depth=64` | 2.26 ms | 542.6 µs | 4.17× | 4.09–4.26 |
| `model_check/incremental-safety|depth=64` | 550.9 µs | 280.6 µs | 1.96× | 1.92–2.01 |
| `model_check/decode-witness|depth=64` | 85.3 µs | 25.2 µs | 3.39× | 2.92–3.93 |
| `model_check/decode-witness|depth=1024` | 1.98 ms | 389.0 µs | 5.08× | 4.84–5.34 |
| `smtlib/build-and-print|terms=770` | 249.6 µs | 199.3 µs | 1.25× | 1.21–1.28 |
| `smtlib/build-and-print|terms=6146` | 14.21 ms | 1.40 ms | 10.15× | 10.12–10.18 |
| `smtlib/print-shared|rounds=10` | 1.42 ms | 5.9 µs | 241.57× | 235.49–247.79 |
| `smtlib/rebuild-interned|terms=6146` | — | 396.1 µs | — | — |
| `smtlib/print|terms=6146` | — | 354.4 µs | — | — |
| `smtlib/eval|terms=6146` | — | 252.9 µs | — | — |
| `smtlib/parse-values|bindings=256` | — | 154.5 µs | — | — |
| `smtlib/parse-values|bindings=2048` | — | 1.23 ms | — | — |
| `smtlib/array-roundtrip|cells=2048` | — | 1.56 ms | — | — |

## js

| Workload | Reference | Tuned | Speedup | Range |
| --- | ---: | ---: | ---: | ---: |
| `model_check/initial-source|states=256` | 225.4 µs | 140.2 µs | 1.61× | 1.32–1.93 |
| `model_check/initial-source|states=2048` | 1.65 ms | 1.60 ms | 1.03× | 0.99–1.08 |
| `model_check/response-query|depth=16` | 389.7 µs | 227.1 µs | 1.72× | 1.57–1.86 |
| `model_check/incremental-safety|depth=16` | 96.6 µs | 96.9 µs | 1.00× | 0.94–1.07 |
| `model_check/response-query|depth=64` | 2.85 ms | 1.51 ms | 1.88× | 1.74–2.02 |
| `model_check/incremental-safety|depth=64` | 605.5 µs | 564.9 µs | 1.07× | 1.06–1.09 |
| `model_check/decode-witness|depth=64` | 72.5 µs | 29.6 µs | 2.45× | 2.26–2.63 |
| `model_check/decode-witness|depth=1024` | 1.43 ms | 587.0 µs | 2.43× | 2.28–2.59 |
| `smtlib/build-and-print|terms=770` | 51.5 µs | 691.0 µs | 0.07× | 0.07–0.09 |
| `smtlib/build-and-print|terms=6146` | 494.7 µs | 5.03 ms | 0.10× | 0.10–0.10 |
| `smtlib/print-shared|rounds=10` | 3.39 ms | 21.5 µs | 157.42× | 144.15–170.73 |
| `smtlib/rebuild-interned|terms=6146` | — | 330.0 µs | — | — |
| `smtlib/print|terms=6146` | — | 1.16 ms | — | — |
| `smtlib/eval|terms=6146` | — | 816.7 µs | — | — |
| `smtlib/parse-values|bindings=256` | — | 341.7 µs | — | — |
| `smtlib/parse-values|bindings=2048` | — | 3.34 ms | — | — |
| `smtlib/array-roundtrip|cells=2048` | — | 3.28 ms | — | — |

## wasm

| Workload | Reference | Tuned | Speedup | Range |
| --- | ---: | ---: | ---: | ---: |
| `model_check/initial-source|states=256` | 605.4 µs | 116.2 µs | 5.21× | 4.64–6.03 |
| `model_check/initial-source|states=2048` | 3.77 ms | 1.24 ms | 3.04× | 2.29–4.35 |
| `model_check/response-query|depth=16` | 973.8 µs | 155.7 µs | 6.25× | 5.83–6.72 |
| `model_check/incremental-safety|depth=16` | 233.6 µs | 126.5 µs | 1.85× | 1.64–2.01 |
| `model_check/response-query|depth=64` | 5.22 ms | 759.5 µs | 6.87× | 5.00–9.24 |
| `model_check/incremental-safety|depth=64` | 1.51 ms | 730.7 µs | 2.07× | 1.68–2.73 |
| `model_check/decode-witness|depth=64` | 341.1 µs | 42.8 µs | 7.97× | 6.58–9.28 |
| `model_check/decode-witness|depth=1024` | 5.40 ms | 635.1 µs | 8.51× | 7.64–9.38 |
| `smtlib/build-and-print|terms=770` | 323.3 µs | 440.2 µs | 0.73× | 0.67–0.83 |
| `smtlib/build-and-print|terms=6146` | 15.51 ms | 2.93 ms | 5.29× | 5.04–5.55 |
| `smtlib/print-shared|rounds=10` | 1.58 ms | 13.5 µs | 117.07× | 104.98–131.95 |
| `smtlib/rebuild-interned|terms=6146` | — | 905.9 µs | — | — |
| `smtlib/print|terms=6146` | — | 620.5 µs | — | — |
| `smtlib/eval|terms=6146` | — | 605.0 µs | — | — |
| `smtlib/parse-values|bindings=256` | — | 382.9 µs | — | — |
| `smtlib/parse-values|bindings=2048` | — | 3.37 ms | — | — |
| `smtlib/array-roundtrip|cells=2048` | — | 4.11 ms | — | — |

## wasm-gc

| Workload | Reference | Tuned | Speedup | Range |
| --- | ---: | ---: | ---: | ---: |
| `model_check/initial-source|states=256` | 344.2 µs | 98.2 µs | 3.51× | 3.50–3.51 |
| `model_check/initial-source|states=2048` | 3.79 ms | 1.82 ms | 2.08× | 1.66–2.51 |
| `model_check/response-query|depth=16` | 771.3 µs | 271.5 µs | 2.84× | 2.56–3.18 |
| `model_check/incremental-safety|depth=16` | 125.7 µs | 70.6 µs | 1.78× | 1.38–2.25 |
| `model_check/response-query|depth=64` | 7.55 ms | 2.42 ms | 3.12× | 2.87–3.42 |
| `model_check/incremental-safety|depth=64` | 939.3 µs | 390.7 µs | 2.40× | 2.16–2.64 |
| `model_check/decode-witness|depth=64` | 72.3 µs | 13.9 µs | 5.20× | 5.16–5.25 |
| `model_check/decode-witness|depth=1024` | 1.99 ms | 370.1 µs | 5.39× | 4.60–6.25 |
| `smtlib/build-and-print|terms=770` | 609.9 µs | 284.5 µs | 2.14× | 1.82–2.59 |
| `smtlib/build-and-print|terms=6146` | 235.19 ms | 4.10 ms | 57.41× | 48.41–69.81 |
| `smtlib/print-shared|rounds=10` | 14.92 ms | 8.4 µs | 1768.23× | 1737.62–1797.36 |
| `smtlib/rebuild-interned|terms=6146` | — | 451.7 µs | — | — |
| `smtlib/print|terms=6146` | — | 961.0 µs | — | — |
| `smtlib/eval|terms=6146` | — | 399.3 µs | — | — |
| `smtlib/parse-values|bindings=256` | — | 145.3 µs | — | — |
| `smtlib/parse-values|bindings=2048` | — | 1.47 ms | — | — |
| `smtlib/array-roundtrip|cells=2048` | — | 1.05 ms | — | — |

## 内部構造の調整前後 / Before and after the storage rework

`smtlib` の最初の実装（1ノードにつき配列6本、`Term` は箱入り、1文字ずつの出力、
UInt64 経由のリテラル出力）から現在の実装への変化。別時点の測定で、µs。
最初の実装の値はバッチ平均、現在の値は上の表の中央値。
最初の実装の測定は文字列を実体化していないため、出力の改善幅は下限。

From the first `smtlib` implementation (six parallel arrays per node, boxed `Term`,
per-character output, literals printed through UInt64) to the current one. Separate runs, in µs;
the first values are batch means, the current ones the medians tabulated above.
The first implementation was measured without materializing the string, so the printing
gains are lower bounds.

| Workload | native | js | wasm | wasm-gc |
| --- | ---: | ---: | ---: | ---: |
| `smtlib/print|terms=6146` | 409 → 354 | 2,690 → 1,160 | 1,280 → 621 | 1,180 → 961 |
| `smtlib/eval|terms=6146` | 337 → 253 | 1,200 → 817 | 794 → 605 | 536 → 399 |
| `smtlib/rebuild-interned|terms=6146` | 533 → 396 | 466 → 330 | 2,060 → 906 | 500 → 452 |
