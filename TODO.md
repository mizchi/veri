# 追加基盤の実装状況

以下の4領域は API・論理モデル・利用例・テストを追加済み。証明と実行時の差分検査の
境界は各項目に記載する。独自公理や `proof_axiomatized` で未対応部分を仮定しない。

## 2. 整数の安全な演算・型変換

- [x] `Int` / `Int64` の `checked_add`、`checked_sub`、`checked_mul`。
- [x] `Int`・`UInt`・`Int64`・`UInt64` の全12方向の値保存変換。
  失敗しうる9方向は `checked_* -> Option`、無条件の拡幅3方向は標準型の値を直接返す。
- [x] 表現可能な場合だけ成功し、数学的整数値を保存する契約・仕様。
  演算本体と変換の `can_*` 判定は両整数モデルで証明。変換結果の仕様は
  `converted_*` で定義し、ネイティブキャスト本体との一致は BigInt で差分検査する。
- [x] 境界値と独立した BigInt モデルによる QuickCheck・標準 tuple / integer shrinking。

実装: `runtime/int32`、`runtime/int64`、`runtime/conversion`。
参照: [Why3 mach.int](https://why3.org/stdlib/mach.int.html)

## 3. バイト列・整数のエンコード

- [x] `bitvector` に `Bv8` / `Bv16` と4幅間の全12方向の符号なし変換。
- [x] Byte / UInt16 / UInt / UInt64 の LE / BE codec と BytesView の読み取り。
  `*_to_le_bytes` / `*_to_be_bytes`、値だけの `read_*`、次の位置も返す `decode_*`。
- [x] `decode(encode(x)) == x`、各バイトの範囲、消費バイト数のモデル上の証明。
  `read_end` は実行時の読み取り境界・消費長を証明。`byte_model` は Byte → Bv8 の
  値保存を証明。ネイティブ codec 本体・UInt16 の値対応は差分検査。
- [x] 切れた入力・境界値・ビューの開始位置を含む QuickCheck・Bytes / tuple shrinking。

実装: `bitvector`、`encoding`、`encoding/bitvector`、`runtime/bytes`。
参照: [Why3 bv](https://why3.org/stdlib/bv.html)

## 4. 代数法則と map / fold

- [x] 結合則・単位元・可換則を、供給された純粋な演算に対する条件として定義。
- [x] 条件を満たす演算について、分割集計・左右の fold・可換演算の順序交換を証明。
- [x] map の恒等則・合成則の帰納的証明、整数和の利用例、法則テスト。
- [x] 任意の演算が法則を満たすという仮定を導入しない。減算の結合則は負例で拒否。

実装: `algebra`。`runtime/list` は core と同じ `fold(init~, f)` / `raise?` と
`from_iter` を提供し、core との比較・callback の例外伝播・順序・長いリストを
含む実行時テストを持つ。論理モデルは純粋な演算が対象であり、
実行時 callback の副作用や関数本体との完全な対応は証明していない。
参照: [Why3 algebra](https://why3.org/stdlib/algebra.html)

## 5. グラフ・到達可能性

- [x] 経路・到達可能性・経路の連結と分解・重みの論理モデル。
- [x] 既存 queue / pqueue を使う探索と、fset の閉じた訪問集合の証明例。
- [x] BFS と非負重み Dijkstra。距離ラベルから最短辺数・最短重みを導く証明と、
  結果の経路・到達集合・距離を独立して検査する `check_bfs` / `check_dijkstra`。
- [x] Floyd–Warshall による全点対の比較、グラフ・操作列の shrinking。
  意図的に誤った「最短辺数＝最短重み」は重み0の1辺へ縮小する。

実装: `graph`、`runtime/graph`。論理的な証明書の定理を証明し、可変状態を使う
BFS / Dijkstra 本体と実行可能な結果検査器は差分テストで検査する段階。
自己辺・多重辺・ゼロ重み閉路・非連結・不正入力・Int 距離のオーバーフローを含む。
構築は `new(vertex_count~)` / `from_array(edges, vertex_count~)` / `from_iter`、
走査は `iter` / `to_array`、構築・探索の失敗は `raise GraphError` に統一。
参照: [Why3 graph](https://why3.org/stdlib/graph.html)

## 利用例と検証

`examples/toolkit` に安全な確保サイズ、BE ヘッダ読み取り、符号変換、集計、経路探索、
有限集合の契約を合成する例を置いた。
`just prove`、`just prove-foundations-machine`、`just prove-machine`、
`just negative`、`just test-backends`、`just test-release`、`just package-check` で検証する。

## 次の証明段階

- ネイティブ整数変換・UInt16・codec の実行時の値保存を直接証明する。
  現行コンパイラの unsupported primitive operator / type を
  `just conversion-capabilities` で再現する。対応が追加されたら生成された意味を確認する。
- 純粋な callback と実行時 map/fold、および可変状態を使う探索・結果検査器の
  全体の対応を証明する。現在のモデル上の定理やテスト成功とは区別する。
