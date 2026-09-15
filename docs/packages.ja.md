# パッケージ一覧と保証

[English](packages.md) | [README](../README.ja.md)

有限集合・Seq・List・Bag・有限 Map・二分木・固定幅 bitvector・全域 array・string・IEEE 浮動小数点の証明用バインディングを提供する。IEEE 754 については **binary32・binary64 / roundTiesToEven (RNE)** の実行結果を検査し、Why3 の IEEE モデル上の性質を証明する。規格全体への適合認証や、MoonBit コンパイラ・CPU の正しさの証明を提供するものではない。

## 構成と保証

| パス | 内容 | 確認すること |
| --- | --- | --- |
| `bounds` | 閉区間の clamp と明示的な半開区間の clamp | 有効な上下限に対し結果が区間内に入り、元から区間内の値を保存する |
| `fset` | Why3 の有限集合への接続 | 空集合・要素追加・和集合の補題 |
| `seq` / `list` | 有限列と帰納的リストのモデル | 連結・長さ・反転・添字、`list/conversions` による相互変換 |
| `bag` / `fmap` | 多重集合と有限写像 | 出現回数・和・更新後の参照・定義域・削除 |
| `bintree` | 論理的な二分木 | サイズ・高さ・所属・走査列の長さ |
| `runtime/list` / `runtime/stack` / `runtime/queue` | 永続リスト・LIFO スタック・FIFO キュー | リストモデルとの構造的な対応と操作の契約 |
| `runtime/pqueue` | Int の最小優先キュー | 整列不変条件・最小値の取り出し・重複数の保存 |
| `runtime/bintree` / `runtime/bintree/search` | 二分木と Int の探索木 | 中間順走査の対応、挿入時の BST 順序と所属の保存 |
| `examples/collections` | 別モジュールからのコレクション利用例 | LIFO・FIFO・最小値・探索の契約合成 |
| `testing/commands` | QuickCheck の操作列生成と shrinker | 再現可能な操作列と、意図的な失敗の `[Push(3)]` への縮小 |
| `ieee754` / `ieee754/float32` | 論理上の binary64 / binary32 と共通の丸めモード | NaN、符号付きゼロ、有限値の自己減算などの補題 |
| `ieee754/conversions` | 論理上の拡幅・縮幅 | binary32 の拡幅往復と NaN 分類の保存 |
| `bitvector` | Why3 の固定幅 bitvector への接続 | 各演算と、剰余を取る整数変換 |
| `bitvector/laws` | bitvector の補題。整数の補題は `laws/integers` | ビット演算則、双方向の変換、符号なし数値の範囲 |
| `arrays` | select/store を持つ全域写像 | 更新後の読み出し、別キーの保存、最後の更新の優先 |
| `strings` | 論理上の SMT string | 連結、長さ、部分文字列、検索、置換 |
| `examples/models` | ライブラリを import する利用例 | 別モジュールでの証明と、bitvector をキー・string を値に持つ array |
| `integer` | 数学的整数と実行時の値の射影 | Int / UInt / Int64 / UInt64 の契約で共用する型 |
| `runtime/uint32` / `runtime/uint64` | 循環加減算の実装 | 両整数モデルで add/sub/less の BV との一致を直接証明し、Z3 参照値とも照合 |
| `runtime/array` | FixedArray の読み書き・swap・fill・範囲コピー | 境界の安全性と操作契約。更新前後の完全な対応は QuickCheck で検査 |
| `arrays/range` | 数学的な範囲と更新前後のモデル | 範囲外の保存・swap・fill・コピーの補題 |
| `runtime/text` | 検証済み入力を持つ SMT 互換文字列 | コードポイント単位の長さ・char_at・substring を Z3 と照合 |
| `examples/bridges` | 実行時ブリッジの利用例 | 別モジュールから契約を組み合わせた証明 |
| `runtime/float32` / `runtime/float64` | 実行時 FP API と参照値比較 | 算術・sqrt・neg/abs・比較・分類・非 NaN のビット往復を照合 |
| `runtime/float_conversions` | 精度変換の検査 | Float ↔ Double を丸め境界を含めて Z3 と照合 |
| `examples/floating` | 実行時 FP の利用例 | Float と Double での丸め精度の違い |
| `runtime/int32` / `runtime/int64` | 符号付き checked add/sub/mul | 正確な数学的結果またはオーバーフロー拒否を両整数モデルで証明し、BigInt と比較 |
| `runtime/conversion` | 符号・幅をまたぐ9種類の checked 変換と3種類の無条件の拡幅 | 表現可能性を証明し、ネイティブ変換結果を BigInt と比較 |
| `encoding` / `encoding/bitvector` | LE/BE の位取りモデル | 8/16/32/64 bit の往復、各バイトの範囲、長さ、BV との対応 |
| `runtime/bytes` | BytesView 上の Byte / UInt16 / UInt / UInt64 codec | 読み取り境界と消費長を証明し、ネイティブ codec を差分検査 |
| `algebra` | 演算の明示的な法則と map/fold モデル | 恒等・合成、順序を保つ分割、monoid の分割集計、可換演算の並べ替え |
| `graph` | 経路・到達性・重み・有限集合の証明 | 連結と分解、閉じた集合、距離ラベルによる最短経路・BFS の証明書 |
| `runtime/graph` | 不変の有向グラフ、BFS・Dijkstra・トポロジー | 検査器全体の証明、独立モデル、グラフと操作列の shrinking |
| `examples/toolkit` | 安全な確保サイズ、ヘッダ読取、集計、経路 | 別モジュールでの契約の合成と実行例 |
| `checks/` | FP・bitvector・array・string の SMT-LIB 2 検査 | 全入力に対する性質と、固定入力の反例 |
| `checks/negative` | 意図的に誤った補題 | 誤った主張を検証経路が成功扱いしないこと |

ルートがライブラリ本体の `mizchi/veri`、`examples/` がそれに依存する独立モジュール
`mizchi/veri-examples`。`moon.work` に両方を登録する。

```text
veri/
├── moon.mod                 # mizchi/veri
├── moon.work                # members: ".", "examples"
├── bounds/
├── bitvector/
├── encoding/
├── algebra/
├── graph/
├── arrays/
├── strings/
├── fset/
├── seq/
├── list/                    # laws, indexed, conversions
├── bag/
├── fmap/
├── bintree/
├── ieee754/
├── integer/
├── runtime/                 # 数値・文字列の対応とコレクション実装
├── testing/commands/
└── examples/
    ├── moon.mod             # mizchi/veri-examples; mizchi/veri@0.1.0 に依存
    ├── models/
    ├── bridges/
    ├── floating/
    ├── collections/
    └── toolkit/
```

workspace 内の依存はローカルの本体へ解決され、レジストリから取得しない。
公開パッケージは `mizchi/veri/bounds`、`mizchi/veri/bitvector`、`mizchi/veri/arrays` などのパスで import する。
本体と examples の証明は `just prove` でまとめて実行する。このツールチェインでは
`moon prove` 単体は現在のモジュールが対象で、examples の証明には `moon -C examples prove` を使う。
証明結果は各モジュールの `_build/verif/` 配下に出力される。

`.mbt` が実装・型・契約、`.mbtp` が論理モデル・補題。`pkg.generated.mbti` で公開 API を確認できる。
`fset`・`seq`・`list`・`bag`・`fmap`・`bintree`・`ieee754`・`ieee754/float32`・`bitvector`・`arrays`・`strings` の抽象型は **証明専用**。実行時の値との対応は、保証を明記した `runtime/` の実装が別途提供する。

最小の利用例:

```moonbit
// moon.pkg で mizchi/veri/ieee754 を import し、proof-enabled を有効にする。
// 以下は .mbtp に置く。
lemma adding_nan_is_nan(x : @ieee754.Float64, y : @ieee754.Float64) where {
  proof_require: @ieee754.is_nan(x),
  proof_ensure: @ieee754.is_nan(
    @ieee754.add(@ieee754.nearest_even(), x, y),
  ),
} {}
```

実行時は `@float64.matches(actual, Bits(expected_bits))` でビット一致、
`@float64.matches(actual, AnyNaN)` で NaN 分類を検査する。
符号付きゼロを取り違えたり、有限値に 1 ULP の差があればビット一致は失敗する。
