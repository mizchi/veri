# veri

[English](README.md) | 日本語

MoonBit の形式検証を使うための小さな基盤。再利用する論理モデル・補題、契約付き実装、実行時の差分検査を用意する。

有限集合・Seq・List・Bag・有限 Map・二分木・固定幅 bitvector・全域 array・string・IEEE 浮動小数点の証明用バインディングを提供する。IEEE 754 については **binary32・binary64 / roundTiesToEven (RNE)** の実行結果を検査し、Why3 の IEEE モデル上の性質を証明する。規格全体への適合認証や、MoonBit コンパイラ・CPU の正しさの証明を提供するものではない。

## パッケージとして使う

公開版を利用する場合は、自分のプロジェクトで依存を追加する。

```sh
moon add mizchi/veri
```

利用するパッケージの `moon.pkg` に import と証明の設定を追加する。

```moonbit
import {
  "mizchi/veri/bounds",
}

options("proof-enabled": true)
```

次のコードを `digit.mbt` に置く。`clamp` は標準の `Int::clamp` と同じ閉区間で、
上限を含む。半開区間には `clamp_half_open(value, lower, upper)` を使う。
どちらも有効な上下限を要求し、証明の事前条件は実行時の境界検査ではない。

```moonbit
pub fn digit(value : Int) -> Int where {
  proof_ensure: result => 0 <= result && result <= 9,
} {
  @bounds.clamp(value, 0, 9)
}

test "clamp includes its upper bound" {
  assert_eq(digit(10), 9)
}
```

```sh
moon test --target js
moon prove
```

この最小例の証明には同梱 Why3 と PATH 上の Z3 を使う。実行時 API の利用だけなら
ソルバーや Node.js、just は不要。論理型・`model`・補題・述語は証明専用で、
通常の実行時コードから呼ぶ関数ではない。複雑な BV・実数の証明で追加のソルバー設定が
必要な場合は、以下のリポジトリの検証手順を参照する。

## リポジトリを検証する

必要なものは MoonBit、`~/.moon/share/why3/` の同梱 Why3 データ、PATH 上の Z3、Node.js 24+、just、unzip。Node スクリプトに npm 依存はない。

`just setup-solvers` は [CVC5 1.3.4](https://github.com/cvc5/cvc5/releases/tag/cvc5-1.3.4) を `_build/solvers/` に取得し、固定した公式 SHA-256 と照合してから展開する。macOS / Linux の arm64 / x64 に対応し、配布物のライセンスを保持する。次回からは取得済みの実行ファイルを使う。既存のものを使う場合は `VERI_CVC5=/path/to/cvc5` を指定すればダウンロード不要。証明レシピと `just verify` はこのセットアップを自動実行する。

```sh
just setup-solvers # 追加ソルバーをローカルに配置（初回のみネットワークが必要）
just doctor       # バージョンと同梱 Why3 の存在を確認
just verify       # 形式検証、負例、参照値、各バックエンドのテスト
```

個別に実行する場合:

```sh
just prove        # MoonBit → Why3 → SMT。workspace の両モジュールを証明
just prove-machine # 機械整数 prelude で bounds・実行時ブリッジ・利用例を証明
just prove-collections-machine # コレクションの実装・利用例を機械整数で証明
just prove-foundations-machine # 順序・算術・実数・IEEE 誤差の契約を機械整数で証明
just core-capabilities # core の関数を契約内から直接呼べるかを調査
just conversion-capabilities # ネイティブ変換と UInt16 の証明変換対応を検査
just array-capabilities # 更新前の状態・snapshot の対応状況と共有参照の拒否を確認
just smt          # FP・bitvector・array・string の UNSAT 証明と SAT の反例
just negative     # 各モデルで意図的な偽命題が証明成功にならないことを確認
just negative bitvector runtime/uint32 runtime/uint64 # 関連する負例だけを選択
just test js      # 実行時検査
just quickcheck js # QuickCheck の性質テストだけを実行
just bench native # core とコレクションを比較し、時間と比率を保存
just bench-backends # 全4バックエンドを順番に計測
just bench-check native 1.0 # 両方の測定順で比率の上限を満たさなければ失敗
just test-backends # JS / wasm / wasm-gc / native
just test-release # 最適化したビルドでも同じ検査
just fp-capabilities # Float/Double の証明変換の対応状況を確認
just vectors      # Z3 から期待値を再生成
just vectors-check # 生成済み期待値と現在の Z3 の結果を照合
just fmt          # フォーマット・公開インターフェース生成
just package-check # 公開用 ZIP から日英 README の最小例を実行・証明
```

手元で確認した環境は moon 0.1.20260904、moonc v0.10.12+1634b282e、Z3 4.16.0、CVC5 1.3.4。
このツールチェインの `moon prove` は `~/.moon/share/why3` を自動で利用する。別の Why3 インストールは行わない。
`just` の証明レシピは、BV、量化式、実数に基づく IEEE モデルに対応する Z3 / CVC5 の経路を `_build/why3/why3.conf` に登録する。
証明結果は各モジュールの `_build/verif/` 配下の `*.proof.json` に出力される。
`just prove` を使う。`moon prove` 単体の既定の変換経路では、整数と BV の対応証明が時間切れになる場合がある。

この節のコマンドはリポジトリのチェックアウト内で実行する。生成したソルバー設定を
自分のプロジェクトで使う場合は、ここで `just prover-config` を実行してから、
利用側で `moon prove --why3-config /path/to/veri/_build/why3/why3.conf` を実行する。
設定はローカルファイルを参照するため、生成元のチェックアウトも保持する。
公開用 ZIP からは開発用 workspace・examples・benchmarks・tools を除外し、
`just package-check` で内容と利用者向けの最小例を検査する。

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
| `runtime/graph` | 不変の有向グラフ、BFS、Dijkstra | 独立距離モデル、実行可能な結果検査、グラフと操作列の shrinking |
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

## Bitvector API

`moon.pkg` で `"mizchi/veri/bitvector"` を import すると4種類の幅を使える。`.mbt` ファイルで型を取り込む:

```moonbit
using @bitvector {type Bv8, type Bv16, type Bv32, type Bv64}
```

`.mbtp` の証明と実行時の契約では `Bv32::add(x, y)`、`Bv64::add(x, y)`、`Bv32::of_integer(n)` などの型メソッドを使う。型はそれぞれ Why3 の `bv.BV8` / `bv.BV16` / `bv.BV32` / `bv.BV64` に対応する。現在の `.mbtp` パーサでは、別パッケージの型メソッドを呼ぶためにこの `using` が必要。従来の幅別パッケージと自由関数から、この API に置き換えた。

公開補題は幅を末尾につけ、`bitvector/laws` の `@laws.addition_wraps32()` / `addition_wraps64()`、`bitvector/laws/integers` の `integer_roundtrip32` / `integer_roundtrip64` として提供する。整数変換の補題は別パッケージに保ち、量化式の探索を抑える。`examples/bitvector/widths.mbtp` では、1つのパッケージの import で、2^32 が Bv32 ではゼロに循環し、Bv64 では保持されることを証明する。これらの補題と利用例は `just prove-machine` でも検証する。

## 安全な整数演算・codec・代数法則・グラフ

`runtime/int32` / `runtime/int64` は `checked_add`・`checked_sub`・`checked_mul`
を提供する。`Some(value)` は正確な数学的結果、`None` は結果が型の範囲外であることを
表す。両整数モデルで契約を証明し、機械整数モデルでは中間演算の安全性も検査する。
`runtime/conversion` は `Int`・`UInt`・`Int64`・`UInt64` の全12方向を
提供する。失敗しうる9方向は `checked_int_to_uint`・`checked_int64_to_int` のように
`checked_` を付け、`Option` を返す。必ず成功する3方向の拡幅
（`int_to_int64`・`uint_to_int64`・`uint_to_uint64`）は core のキャストで値を直接返す。
`can_*` で正確な範囲判定を証明し、`converted_*` で値保存の仕様を定義する
（拡幅の結果をこの仕様に渡すときは `Some` で包む）。
組み込み数値型には外部パッケージから直接公開メソッドを追加できないため、
標準型を直接受け取る関数として提供する。
現行の証明フロントエンドはネイティブ変換を扱えないため、その対応は仮定せず
独立した `BigInt` 演算で差分検査する。`just conversion-capabilities` で
UInt16 の変換を含む対応状況を記録する。

`runtime/bytes` は MoonBit の型名に合わせ、`byte_to_bytes` と
`{uint16,uint,uint64}_to_{le,be}_bytes` を提供する。core の `to_le_bytes` /
`to_be_bytes` と同じ命名で、32 bit 整数は実行時の `UInt` に合わせて `uint` とする。
`read_byte`・`read_{uint16,uint,uint64}_{le,be}` は
`(data : BytesView, offset : Int)` を受け取り、標準型の値を `T?` で返す。
逐次解析用の `decode_byte`・`decode_{uint16,uint,uint64}_{le,be}` は
`Decoded[T]?` を返し、`value` とビュー先頭からの `next_offset` を持つ。
負数・オーバーフロー・切れた入力は `None`、読み取り後の余剰バイトは許容する。
`read_end` は範囲判定と消費長を証明する。`encoding` は LE/BE の往復、バイトの範囲、
長さを証明し、`encoding/bitvector` で Bv8/Bv16/Bv32/Bv64 と接続する。
`runtime/bytes.byte_model` は Byte と Bv8 の値保存を証明する。
ネイティブ codec の値、UInt16 のキャスト、ビュー内オフセットは差分検査の対象で、
codec 本体の全入力の値保存は未証明。16 bit は MoonBit の `UInt16` を使い、
エンコード結果は新しい不変の `Bytes` を返す。

`algebra` は供給された純粋な演算に対する `associative`・`identity`・`commutative`・
`monoid` と、`runtime/list.List` 上の構造的モデルを定義する。`fold_split` は法則を
仮定せず、`fold_partitions` / `fold_directions` は monoid、`reorder_partitions` は
さらに可換則を要求する。`map_identity` / `map_composition` は構造帰納法で証明する。
実行時の `List::map(f)` / `List::fold(init=initial, f)` は core/list と同じ
`raise?` の callback を左から順に呼び、例外をその場で伝播する。
`List::from_iter` は標準 `Iter` を順に消費する。core との QuickCheck 比較と shrinking、
法則・例外時の呼び出し順・長いリストをテストする。callback の副作用は純粋なモデルの対象外。
任意の演算が法則を満たすという仮定は追加しない。

`runtime/graph.Graph::from_array(edges, vertex_count=n)` は頂点 `0..<n`、非負の
Int 重みを持つ有向グラフを検査し、入力辺をコピーする。自己辺と多重辺を許容する。
`Graph::new(vertex_count=n)` は辺のないグラフ、`from_iter(edges, vertex_count=n)` は
標準 `Iter` から構築する。`iter()` / `to_array()` は始点の頂点番号順、同じ始点の辺は
入力順で走査する。構築と探索は値を直接返し、`raise GraphError` により
MoonBit の `try ... catch` でエラーを扱える。
`bfs(source)` は最小辺数、`dijkstra(source)` は最小重みを求め、既存の FIFO queue と
最小 priority queue を使う。結果の `distance(vertex)` と `path_to(vertex)` は、
無効・到達不能な頂点で `None` を返す。経路は始点と終点を含む新しい配列。
無効な始点はエラーになり、到達可能な頂点の最小距離が Int を超える場合もエラーにする。
オーバーフローする迂回路があっても、表現可能な最短経路は拒否しない。
`check_bfs` / `check_dijkstra` は経路・辺の不等式・到達集合の閉包を独立して検査する。
この診断用検査は経路の再構成と隣接辺の走査により最悪 O(V(V+E)) 時間で、探索時には自動実行しない。

`graph` は経路の連結・分解、重みの加法性、`fset` 内の閉包、距離ラベルからの
最短性の証明書を用意する。論理経路は後続頂点列（始点を省き、終点を含む）で、
実行時の `path_to` は始点も含む。探索と実行可能な結果検査は、独立した
Floyd–Warshall モデルと比較し、ゼロ重み閉路・非連結・オーバーフローもテストする。
可変状態を使うアルゴリズム本体全体は未証明。`examples/toolkit` に実行例と、
整数演算・集計・有限集合の契約を合成する証明例がある。

## 順序・整数論・実数と誤差評価

| パッケージ | 内容 |
| --- | --- |
| `relations` | 同値関係、前順序、半順序、全順序、逆順、辞書順。法則は渡された関係に対する明示的な述語 |
| `seq/order` | 整列、整列済み置換、区間内の置換、交換、swap の補題。添字と区間は数学的整数 |
| `integer` / `integer/laws` | 算術、絶対値、min/max、Euclidean 除算とゼロ方向への除算、その剰余の対応 |
| `integer/aggregate` / `integer/aggregate/laws` | 非負整数乗、半開区間の和と分割則 |
| `number` / `number/laws` / `number/parity` | 整除、GCD、互いに素、偶奇と補題 |
| `runtime/number` | UInt の GCD、Int の安全な除算・剰余、正の法に対する Euclidean 剰余 |
| `real` / `real/laws` | 証明専用の数学的実数、整数の埋め込み、floor/ceil、距離と誤差の合成 |
| `ieee754/error` / `ieee754/error/operations` | 実数への射影、丸め、binary32/64 の演算誤差と入力誤差の伝播 |
| `examples/foundations` | 別モジュールから順序、GCD、実数、丸めの契約を利用する例 |

`relations` は [Why3 relations](https://why3.org/stdlib/relations.html) の法則を、関係 `(T, T) -> Bool` に対する述語として表す。任意の比較関数を全順序だと仮定しない。辞書順の推移性には両成分の順序の法則を要求する。`seq/order` の `sorted_permutation` は整列と要素の重複数の保存を合わせた仕様であり、ソート実装そのものではない。[Why3 seq](https://why3.org/stdlib/seq.html) の交換・置換の定義を利用する。

除算は規約を明示する。`integer.div(-7, 3) = -3`、`integer.modulo(-7, 3) = 2` に対して、`integer.trunc_div(-7, 3) = -2`、`integer.trunc_mod(-7, 3) = -1`。論理上の除算・剰余の法則には非ゼロの除数が必要。`runtime/number.div_rem` はゼロ除算と `Int::min_value / -1` に `None` を返す。`euclidean_mod` は法が正の場合だけ `Some(r)` を返し、`0 <= r < modulus` を保証する。[Why3 int](https://why3.org/stdlib/int.html)

`runtime/number.gcd` は Euclid の互除法を使い、UInt の全範囲で [Why3 number.Gcd](https://why3.org/stdlib/number.html) との一致と停止性を証明する。`gcd(0, 0) = 0`。除算・剰余・GCD は通常の整数モデルと機械整数モデルの両方で検証する。実行時テストでは独立した共通約数の列挙、Int64 による除算の再構成、符号と境界を検査し、QuickCheck の標準 tuple shrinker を使用する。

実数は丸めのない仕様用の型で、実行時 Double への型変換ではない。除算の法則には非ゼロの分母が必要。`real.within(actual, ideal, tolerance)` は `|actual - ideal| <= tolerance` を表し、負の許容誤差では成立しない。入力誤差を持つ加算の合成、距離の三角不等式、整数の埋め込みを証明する。[Why3 real](https://why3.org/stdlib/real.html)

RNE で理想的な実数結果を `z` とすると、オーバーフローしない場合の誤差上限は以下になる。

- binary32: `2^-24 * |z| + 2^-150`
- binary64: `2^-53 * |z| + 2^-1075`

上限は [Why3 ieee_float](https://why3.org/stdlib/ieee_float.html) の `round_bound_ne` に基づく。定数は証明上の正確な実数として構成し、subnormal を含む。`ieee754/error/operations` は有限な入力・`no_overflow`・除算時の非ゼロ除数を前提に、加減乗除の実数結果との差を評価する。加算には入力誤差 `ex + ey` と今回の丸め誤差を合成する補題もある。`checks/*/half-subnormal-error.smt2` は、相対誤差項だけでは不足する具体例を native SMT floating-point で確認する。

これらは Why3 の IEEE モデルについての証明であり、実行時 Float/Double と実数射影との一致を新たに仮定しない。実行時との対応は、既存の Z3 参照値との比較および `fp-capabilities` の報告範囲に従う。

`just prover-config` は既存の native SMT と整数による BV 検証に加え、Why3 の浮動小数点の公理・丸め誤差補題を保持する Z3 / CVC5 の経路、および定義を等価な公理として符号化して補題の照合を助ける Z3 の経路を生成する。CVC5 は列の量化式や非線形な実数の誤差評価で Z3 を補完する。同梱 Why3 のファイルは変更せず、独自の仮定や `proof_axiomatized` は追加しない。通常は `just prove`、機械整数での追加検証は `just prove-foundations-machine` を使う。`just verify` は両方と負例検査を実行する。

## 実行時コレクションの API

独自型には `List::new()`・`Stack::new()`・`Queue::new()`・`IntMinQueue::new()`・
`IntSet::new()`・`Tree::new()` とメソッドを用意する。更新は新しい値を返し、
元の値も引き続き使える。`IntMinQueue` は重複を保持する Int 専用の最小優先キュー、
`IntSet` は重複のない Int の集合。既存の自由関数は同じ契約付き実装へのエイリアスとして残す。

```moonbit
// "mizchi/veri/runtime/queue" を import。
test "persistent queue and Iter" {
  let original : @queue.Queue[Int] = @queue.Queue::new()
  let queue = original.push(1).push(2)
  assert_true(original.is_empty())
  assert_eq(queue.iter().map(x => x * 2).to_array(), [2, 4])
}
```

`iter()` は中間の配列を作らず、独立した走査状態を返す。順序はリスト順、スタックの
先頭順、キューの FIFO 順、最小優先キュー・集合の昇順、木の中間順。
イテレーターと配列変換の対応は実行時テストで検査し、証明契約は付けていない。
List のメソッド名は core に合わせて `prepend`・`concat`・`rev` とし、自由関数の
`cons(value, list)`・`append(left, right)`・`reverse(list)` も使える。

## FixedArray の更新と範囲操作

`runtime/array` は組み込みの `FixedArray[T]` を直接更新する。範囲は
`Range { start, count }` で指定し、`[start, start + count)` を意味する。
更新操作は成功時に `true`、不正な添字・範囲では変更せず `false` を返す。
配列末尾の空範囲も有効。
`Range` は `#valtype` の小さなレコード。フィールド名で開始位置と個数を区別し、
証明対象でも呼べる位置引数の API にしている。現行の証明変換は契約付き本体での
名前付き引数の呼び出しに未対応。`Range` の構築自体は境界検査を行わず、
不正な値は各操作が検査する。

| API | 動作 |
| --- | --- |
| `valid_range(length, range)` | 極端な不正入力でも加減算をオーバーフローさせず範囲を検査 |
| `set(array, index, value)` | 単一要素の書き込み |
| `swap(array, left, right)` | 2要素の交換。同じ添字も有効 |
| `fill(array, value, range)` | 指定範囲を同じ値で埋める |
| `blit(source, target, source_range, target_start)` | 同一配列の重複範囲を含むコピー |
| `blit_disjoint(source, target, source_range, target_start)` | **異なる配列間**の契約付きコピー |
| `copy_within(array, source_range, target_start)` | 同一配列内のコピー。重複範囲でも更新前のコピー元の値を使う |

`set`・`swap` は定数時間、範囲更新は O(count) 時間・定数の補助領域で動作する。
`copy_within` は大きい添字へ移動するときに後ろから書き込み、一時配列を作らない。
これは計算量の説明であり、core との実測性能の同等性を保証するものではない。
`blit` は参照の同一性を調べ、同一配列には `copy_within`、別配列には
`blit_disjoint` を使う。この振り分けは実行時テストで検査し、証明契約は持たない。
証明対象のコードでは `copy_within` または `blit_disjoint` を選ぶ。
後者に同じ配列を渡す呼び出しは Why3 が共有参照として拒否する。
`range_in_bounds(length, start, count)` は数学的な端点を扱う **証明専用** の述語。
実行時の範囲検査には `valid_range(length, range)` を使う。

```moonbit
// "mizchi/veri/runtime/array" を import。
test "range updates" {
  let xs : FixedArray[Int] = [0, 1, 2, 3]
  assert_true(@array.fill(xs, 9, { start: 1, count: 2 }))
  assert_true(@array.copy_within(xs, { start: 0, count: 3 }, 1))
  assert_eq(xs, [0, 0, 9, 9])
}
```

通常・機械整数の両モデルで、範囲検査、安全な添字アクセス、整数演算の範囲、
ループの停止性を証明する。加えて、`set` が書く値、`swap` の交換する値
（関数内の assertion）、`fill` の全対象要素、`blit_disjoint` の対象要素と異なるコピー元の
一致を証明する。公開される `swap`・`copy_within` の契約は成功条件・範囲まで。
`examples/bridges.fill_and_read` では別モジュールから `fill` と `get` を合成する。

`arrays/range` は更新前後の完全な仕様として `unchanged_outside`・`filled`・
`copied`・`exchange` を定義する。7個の補題は単一書き込み、swap とその取り消し、
空操作、fill・コピーを1要素延ばすときの性質を証明する。添字は数学的整数で、
[Why3 map](https://why3.org/stdlib/map.html) の範囲等価・交換を利用する。
`copied` は重複範囲でも必ず**更新前**のコピー元を参照する。
このモデルの証明だけで実行時実装との完全な対応が証明されるわけではない。

現行コンパイラでは契約内の `old(...)` が使えず、`proof_let` による snapshot は
内部の assertion failure になる。そのため、更新前後の完全な対応、更新範囲外の保存、
失敗時に変更しないこと、重複コピーの内容は、snapshot を使う独立した参照実装と
QuickCheck で比較する。**実行時関数についての全入力の形式証明には未対応**。
配列更新の8個の性質は各1,000件で、操作列、全幅の整数、有効範囲付近の入力を検査し、
core のタプル・配列 shrinker を使う。誤った前向きコピーが3要素の重複ケースまで
縮小される回帰テストもある。負例の証明検査では、誤った fill の値、範囲の桁あふれ、
モデルでの範囲外書き込み、変更済みコピー元の参照を拒否する。

`just array-capabilities` はコンパイラの制約と共有参照の拒否を検査し、
`_build/array-capabilities.json` に記録する。`just verify` にも含む。
ローカルの証明注釈では配列参照を predicate にまとめ、コンパイラが更新関数を
Why3 の ghost コードとして扱う問題も回避している。新たな仮定付き契約や独自公理は
追加していない。実装状況と証明範囲はリポジトリの [TODO.md](TODO.md) を参照。

## QuickCheck による性質テスト

`bounds/` と `runtime/` の性質を `moonbitlang/core/quickcheck` で、
固定 seed `20260914` / `20260915` により検査する。通常は1,000件、
グラフは500個と編集操作列200件について、全始点・終点を Floyd–Warshall と比較する。
生成サイズは最大64、コレクション操作列と赤黒木は最大128、グラフは最大7頂点・入力辺48本。`just quickcheck js`（または `wasm`、
`wasm-gc`、`native`）で実行でき、`just test`・`just test-backends`・
`just test-release`・`just verify` にも含まれる。

検査対象は clamp の範囲と単調性、整数の循環演算と順序、配列の読み取りと更新、
SMT の文字集合とコードポイント単位の位置、浮動小数点のビット表現・分類・
符号操作・演算の恒等則・精度変換の往復。
文字列の操作はスカラー値を順番に走査する独立の参照処理と照合する。
浮動小数点は `UInt` / `UInt64` のビット列から生成し、特殊値と指数の全範囲を
生成対象にする。非 NaN はゼロの符号も含めて比較し、NaN は分類だけを比較する。
NaN ペイロードの保存は要求しない。

コレクションでは、リスト、Stack / Queue の操作列、優先キュー、木の走査、
BST の挿入・検索を独立した配列モデルと比較する。最小優先キューは、
MoonBit core の優先キューに `Reverse[Int]` を渡した実装とも照合する。
core の既定は最大値を返すため、順序を反転させる。
各操作では、以前の永続データ構造の内容が変わらないことも確認する。

例えば `mizchi/veri/runtime/uint32` と `moonbitlang/core/quickcheck` を
`for "test"` で import すると、次のように書ける。

```moonbit
test "quickcheck: wrapping roundtrip" {
  @quickcheck.check(
    (input : (UInt, UInt)) => {
      let (value, delta) = input
      @uint32.sub(@uint32.add(value, delta), delta) == value
    },
    count=1000,
    seed=20260914,
  )
}
```

失敗時は QuickCheck が縮小した反例を出力する。同じ性質と seed で再実行すると
再現でき、seed を変えると別の再現可能な標本を検査できる。
これは実行時の標本検査であり、Z3 の参照値テストや形式証明と併用する。
IEEE 全入力への適合証明を与えるものではない。

`testing/commands` で `Push(Int) | Pop | Peek | Clear` に対する
`moonbitlang/core/quickcheck/shrink.Shrink` を実装する。core の Array shrinker が
操作列の一部を削除し、Command の shrinker が core の Int shrinker を使って
Push の値を縮める。二分木には、部分木への置き換えと内部ノードの値の縮小を
再帰的に行う shrinker を用意した。これらは `max_shrinks=1000` として探索量を
制限するため、あらゆる性質で大域的に最小の反例が得られるとは限らない。

別の回帰テストでは「Push される値はすべて3未満」という意図的に偽の性質を
`@quickcheck.report` に渡し、`counterexample=[Push(3)]` まで縮小されたことを
検査する。これは意図的に偽の `quickcheck:*` テストで、失敗と縮小の経路を確認するもの。
グラフでも「最短辺数と最短重みは等しい」という偽の性質を、重み0の1辺
（`counterexample=[0]`）へ縮小する。
1,000件成功する正例の性質には数えない。

## コレクションのベンチマーク

`benchmarks/collections` で [MoonBit のベンチマーク API](https://docs.moonbitlang.com/ja/latest/language/benchmarks.html)
を使い、`moon bench --release --no-parallelize` で計測する。
14種類の処理を256要素と2,048要素で実行し、各バックエンドで34組を比較する。
木の直接 `to_array()` を2処理追加し、従来の `inorder().to_array()` も残している。
実装の測定順を逆転した2回の測定を行い、各回は自動調整した5バッチ。
`Bench.keep` で結果を保持し、同じ最適化済みバックエンド上で、計測前に正確な
出力の一致を確認する。空入力と繰り返し実行も別途テストする。

| 処理 | core の比較対象 | 計測する範囲 |
| --- | --- | --- |
| List | `core/list` | 反転・連結と配列への変換、長さ |
| Stack | `core/list`・組み込み `Array` | 全要素の push と、新しい配列への取り出し |
| Queue | `core/queue` | 投入と取り出し、構築済みキューへの連続 peek |
| 最小優先キュー | `core/immut/priority_queue`・`core/priority_queue` に `Reverse[Int]` を指定 | 重複を含む入力の push と取り出し。シャッフル順・昇順 |
| BST | `core/immut/sorted_set` | 挿入後、全キーと同数の存在しないキーを検索。シャッフル順・昇順 |
| 二分木の走査 | `core/immut/sorted_set` | 平衡した木・左に偏った木から同じ値を配列化。中間リスト経由と直接配列化を別々に計測 |

汎用二分木には直接対応する core の型がないため、走査の比較対象は整列した値の
列挙であり、任意の形状の木の操作ではない。可変の比較対象は現在の状態だけを使い、
スナップショット保持を模擬するためのコピーは加えない。入力の生成と読み取り用の
構造の準備は計測外に置き、build/drain・build/find では毎回の構築と出力処理を含める。
連続 peek は pop せず同じキューを読む。更新時に正規化する現実装では、反転を繰り返さない。
コンパイラが反復する読み取りをループ外へ移す場合もあり、個々の関数呼び出しの
遅延ではなく、最適化後の処理全体の時間を表す。

`just bench native`（または `js`・`wasm`・`wasm-gc`）で、生の出力・JSON の統計・
Markdown の比較表を `_build/benchmarks/collections-<target>.*` に保存する。
ツールチェイン、CPU、OS、リポジトリのリビジョン、インストール済み core ソースの
ハッシュも記録する。実行時実装とベンチマークのソースにも別々の SHA-256 を記録する。時間は2回のバッチ中央値の平均で、単位はマイクロ秒。
比率は **veri/core** なので、1を超えると veri が遅い。2回の比率の範囲は測定順に
よる変動を示すもので、信頼区間ではない。結果の欠落、不正な時間、計測プロセスの
失敗は、レポート生成を失敗させる。

`just bench-check native 1.0` は新しく計測し、いずれかの比較が片方の測定順でも
指定した上限を超えれば非ゼロで終了する。上限をまたぐ結果は判定保留として扱い、
このチェックでは失敗にする。時間は環境負荷やハードウェアに依存するため、
ベンチマークは `just verify` から独立させている。

[最新のチューニング結果](benchmarks/collections/TUNING.md) では、現実装は
**一律に core より遅くならないという目標を満たしていない**。
表現・確保・アルゴリズムの違いを含む比較であり、証明契約だけの追加コストを
切り分けるものではない。証明専用の `seq/list/bag/fmap/bintree` バインディングには
計測対象となる実行時の操作がない。利用するバックエンドと処理内容で再測定する。
[2026-09-14の測定結果](benchmarks/collections/RESULTS.md) は、以前の skew heap
実装の記録として保存している。

## コレクションのモデルと実装

| 論理パッケージ | 同梱 Why3 の理論 | 意味 |
| --- | --- | --- |
| `seq` | `seq.Seq`・`Reverse`・`Mem`・`Occ`・`Permut` | 数学的な長さと添字を持つ有限列 |
| `list` / `list/indexed` | `list.List`・`Length`・`Append`・`Reverse`・`NthNoOpt`・`NumOcc` | 帰納的リスト。添字と出現数は必要に応じて追加 import |
| `list/conversions` | `seq.OfList`・`seq.ToList` | 論理リストと有限列の変換 |
| `bag` | `bag.Bag` | 多重集合。和は出現回数を加算し、差は0で切り詰める |
| `fmap` | `fmap.Fmap` | 有限集合の定義域を持つ写像 |
| `bintree` | `bintree.Tree`・`Size`・`Height`・`Occ`・`Inorder`・`Preorder` | 二分木の内容と走査モデル |

論理上の長さ・出現回数・添字は、上限のない `integer.Integer` を使う。
`seq.get/update` は `0 <= index < length`、`slice(start, stop)` は
`0 <= start <= stop <= length` を満たす範囲で使う。`stop` は範囲に含めない。
論理リストの `head/tail` は非空、`list/indexed.get(index, xs)` は範囲内の添字、
`fmap.find` は `mem(key, map)` が成立するキーを前提とする。
これらは実行時の境界検査ではなく、規定された範囲外の値は未規定。

**`runtime/*` は core のエイリアスではなく、契約付きの独立実装。**
永続データ構造を実装し、実際のコンストラクターと Why3 の
リスト・多重集合・木を再帰的なモデルで結ぶ。Stack / Queue は Why3 の LIFO / FIFO、
優先キューは最小値と重複数の仕様に対応する。Why3 の可変データ構造の抽象的な
`val` API を実行可能な実装として取り込むものではない。

core を直接呼ぶラッパーに契約を付ける方法も調査した。現在のツールチェインでは
`core/list.length`、`core/queue.peek`、`core/immut/priority_queue.push`、
`core/immut/sorted_set.contains` は契約付き関数から呼ぶと `Error 4207` になる。
`just core-capabilities` で再現でき、通常の型検査が通ることも確認する。
[MoonBit の検証仕様](https://docs.moonbitlang.com/en/latest/language/verification.html)
では契約内からの呼び出しに制限がある。`#proof_import` は論理演算の接続であり、
core の実装本体の正しさを証明するものではない。core に証明可能な契約を追加するか、
コンパイラ側で対応することが、直接再利用と実装の対応証明を両立するために必要。
`#proof_axiomatized` に置き換えて対応を仮定する方法は採用していない。


| 実行時パッケージ | 操作と表現 | 計算量 |
| --- | --- | --- |
| `runtime/list` | `empty/cons/uncons/is_empty/append/reverse/length`。不変の連結構造 | 基本操作 O(1)、連結・反転・長さ O(n) |
| `runtime/stack` | `empty/push/pop/peek/is_empty`。pop の戻り値を兼ねる連結セル | O(1) |
| `runtime/queue` | `empty/push/pop/peek/is_empty`。前方リストと逆順の後方リスト | Push/peek O(1)、pop は償却 O(1)・最悪 O(n) |
| `runtime/pqueue` | `empty/push/pop/peek/is_empty`。Int の two-pass pairing heap、重複を保持 | Push/peek O(1)、pop O(k)。k は根の子の数、最悪 O(n) |
| `runtime/bintree` | `empty/node/inorder/to_array`。汎用二分木 | 構築 O(1)、走査 O(n) |
| `runtime/bintree/search` | `empty/insert/contains`。重複のない Int の赤黒木 | Insert/contains O(log n) |

計算量は公開 API から構築した状態での実装の説明であり、形式証明の対象にはしていない。Queue は更新後の前方リストを
正規化し、繰り返しの peek で反転しない。Queue の償却計算量は、単一の
更新履歴に対するもの。古いスナップショットから分岐すると同じ処理を繰り返す場合がある。
優先キューは [pairing heap](https://www.cs.cmu.edu/~sleator/papers/Pairing-Heaps.htm) の
隣接する子を左から組にして結合し、その結果を右から結合する方式を使う。
2つの走査は末尾再帰で、停止性・内容と順序の保存を証明する。
組み合わせと結合は結果のセルを直接構築し、一時的な根の確保を省く。
赤黒木は [Okasaki の挿入アルゴリズム](https://www.cambridge.org/core/journals/journal-of-functional-programming/article/redblack-trees-in-a-functional-setting/62BC5EA75A2C95E3F6EE95AE3DADF0E5)
に基づく。core の完全二分ヒープ・サイズ平衡木とは実装が異なる。

BST の `valid(tree)` は従来と同じ厳密な探索順序を表し、`empty` が確立して `insert` が保存する。
回転を含む挿入・探索について、順序・要素の保存と検索結果を証明する。赤黒の不変条件
（黒い根、赤の連続禁止、等しい黒高さ）は shrinking 付き QuickCheck と長い昇順・降順の
テストで検査する。色の不変条件の保存と計算量の形式証明、削除は未実装。

探索木の型は、色を内部に持つ `@search.IntSet` に変更した。
`@tree.Tree[Int]` を直接渡すコードは `@search.empty()` と `insert` で構築し、列挙には
`@search.to_array(tree)` を使う。仕様側のモデルは `@tree.model` から `@search.model` に移る。
汎用の `runtime/bintree.Tree[T]` は引き続き任意形状の木に使う。
List の長さは末尾再帰、木の inorder は継続リストを使う線形走査とした。
inorder は左の枝を末尾再帰にするが、右の枝と List の append は呼び出しスタックを使う。
直接 `Tree::to_array()` は明示的な作業スタックで両方向の深い木に対応し、中間リストを
確保しない。この配列変換は独立モデルとの QuickCheck と2万段の木で検査する。
Stack/Queue/IntMinQueue/IntSet のラッパーは `#valtype`、小さな操作は `#inline` で
余分なラッパー確保を抑える。更新には `#owned` も使い、不要な参照カウント操作を減らす。
Stack は保存したセルが `(value, rest)?` そのものなので、pop で別のタプルを確保しない。
これらは実行時コードの最適化であり、既存の内容・順序の契約を変更しない。
`proof_require`・`proof_ensure`・`proof_assert` と `.mbtp` は実行時の検査ではない。

`pop/uncons/peek` は空入力に `None` を返す。リストの `length` は数学的な長さが
Int に収まること（最大 2,147,483,647）を要求し、機械整数 prelude でも確認する。
配列変換の補助関数 `from_array/to_array` は実行時の性質テストで検査し、対応の契約は
まだ付けていない。永続性が保つのはコンテナーの構造で、格納した値自体は可変の場合がある。
`examples/collections` でモジュールをまたいだ契約の合成を示し、
`just prove-collections-machine` で同じ実装と利用例を機械整数でも証明する。

## バインディングの接続先

MoonBit 側の API は **Why3 の理論**に接続する。Why3 のソルバードライバが、対応する演算を SMT-LIB 2 に変換する。

```text
MoonBit の契約 / .mbtp → Why3 の理論 → SMT-LIB 2 → Z3 / CVC5
checks/**/*.smt2 ──────────────────→ SMT-LIB 2 → Z3
```

`#proof_external` が論理型、`#proof_import` が論理演算の対応を定義する。
`.smt2` の検査は MoonBit / Why3 を経由しない別経路。
これらは証明用 API であり、実行時に Z3 を呼ぶ FFI や汎用 SMT-LIB 2 式ビルダーではない。

| パッケージ | Why3 の理論 | 主な演算 |
| --- | --- | --- |
| `bitvector` | `bv.BV8` / `bv.BV16` / `bv.BV32` / `bv.BV64` | `add/sub/mul`、`udiv/urem`、`sdiv/srem`、`bw_and/or/xor/not`、`shl/lshr/ashr`、`ult/ule/slt/sle` |
| `arrays` | `map.Map`、`map.Const` | `select`、`store`、`const_array`、外延的な `eq` |
| `strings` | `string.String` | `concat`、`length`、`char_at`、`substring`、`contains`、`prefix_of`、`suffix_of`、`index_of`、`replace`、`to_integer/from_integer`、`lt/le` |

bitvector は固定幅で、8 / 16 / 32 / 64 bit を提供する。signed / unsigned はビット列の型ではなく演算で区別し、
加減乗算は 2^width を法として循環する。シフト量も同じ幅の bitvector で、幅以上のシフト量を剰余で折り返さない。
`Bv32::width()` / `Bv64::width()` は `integer.Integer` の 32 または 64。
シフト演算に渡す bitvector 表現には `width_bv()` を使う。SMT モデルでは符号なしのゼロ除算は全ビット1になるが、
実行時の除算についての保証ではない。`to_bv8/to_bv16/to_bv32/to_bv64` は4幅の間の符号なし変換で、拡幅では数値を保存し、縮幅では下位ビットを残す。任意幅、切り出し、符号拡張はまだ公開していない。
`of_integer` は最初に 2^width で剰余を取り、負数や幅を超える数学的整数も変換できる。
`to_integer` は符号なし数値、`modulus()` は 2^width を返し、`in_range` は符号なしの範囲を判定する。
`to_integer(of_integer(n)) = n mod 2^width` と `of_integer(to_integer(v)) = v` を補題で証明する。

`SmtArray[K, V]` はすべてのキーに値を持つ全域写像で、長さ・境界検査・破壊的更新はない。
`store` は新しい写像を返す。メモリのモデルには使えるが、実行時の配列の境界や動作をそれだけで証明するものではない。

`Text` は U+0000..U+2FFFF を文字集合とする SMT の文字列モデル。
長さはコードポイント数なので、この範囲内の補助平面の文字も1であり、
MoonBit の実行時の UTF-16 長とは異なる。`char_at` の返り値は文字列、`substring` の引数は開始位置と個数。
不正な位置は空文字列、検索失敗は -1 となり、`replace` は最初の一致を置換する。
`to_integer/from_integer` は SMT の非負整数の10進変換規則に従い、値・長さ・添字は両整数 prelude で `integer.Integer` を使う。
実行時の添字は `@integer.from_int(index)` で射影する。これらは証明用であり、実行時のキャストではない。
`Text` と MoonBit `String` の暗黙変換はなく、正規表現のバインディングもまだ含まない。

`examples/models/models.mbtp` に `SmtArray[Bv64, Text]` を組み合わせる証明例がある。
`just smt` は対応する理論上の性質と具体的な反例を確認する。各モデルの負例検査が保証するのは
誤った主張が証明成功にならないことまでで、具体的な反例は直接実行する SAT 検査で別途示す。

## MoonBit の実行時型との対応

| 実行時型 | モデル / アダプター | 現在の保証 |
| --- | --- | --- |
| `Int`・`UInt`・`Int64`・`UInt64` | `@integer.from_int/from_uint/from_int64/from_uint64` → `Integer` | 選択した MoonBit prelude から数値を取り出す証明専用の射影 |
| `UInt`・`UInt64` | `runtime/uint32`・`runtime/uint64` | `model` で Bv32/Bv64 に写し、add/sub/less と BV 演算の一致を両整数モデルで直接証明 |
| `Int` / `UInt`・`Int64` / `UInt64` | 32 / 64 bit のビット表現 | 組み込みの加減乗算・ビット演算・符号付き/符号なし比較・有効なシフトと循環演算アダプターを Z3 の 48 ケースで照合 |
| `FixedArray[T]` | `@runtime_array.model(a)` → `SmtArray[Integer, T]` と `a.length()` | 読み取り・範囲検査・更新の契約を両モデルで証明。更新前後の証明範囲は配列の節を参照 |
| `String` | `@text.from_string(s)` → `@text.Text?` | UTF-16 と共通の文字集合を検査し、長さ・char_at・substring を Z3 の 72 ケースで照合 |
| `Float` / `Double` | binary32 / binary64 のビット表現 | 各型 122 演算ケースと精度変換 62 ケースを Z3 と照合。実演算との全入力の一致証明は未対応 |

`Integer` は上限のない **証明専用** の抽象型。機械整数 prelude を選んでも数学的整数として扱える。
射影は論理関数であり、実行時の数値キャストではない。
既定の prelude は `UInt` も上限のない整数として扱うため、循環演算の契約には
`0 <= x,y <= MAX` を明記する。対応する符号なし実行時型の全値はこの条件を満たす。
機械整数 prelude は中間演算のオーバーフローを禁止するので、アダプターは分岐でそれを回避する。
剰余算術の仕様を維持し、次の直接の対応も契約で証明する。

```text
model(add(x, y)) = bv.add(model(x), model(y))
model(sub(x, y)) = bv.sub(model(x), model(y))
less(x, y)       = bv.ult(model(x), model(y))
```

対応する符号なし実行時型の全入力について成立し、数学的モデルでは範囲の事前条件を明記する。
`model_preserves_value` は符号なし数値がモデルへの変換で保存されることを証明する。
`model` は証明専用で、実行時に使う検証済み関数は `add`・`sub`・`less`。
保証の対象はこれらのアダプターと信頼する MoonBit / Why3 の変換であり、任意の組み込み演算全体ではない。

このツールチェインではビット演算の組み込み命令を証明へ変換できない箇所がある。
実行時との対応は差分テストで検査し、`proof_axiomatized` で仮定しない。
シフトの参照検査は `[0, width)` のシフト量に限定する。幅以上のシフトとゼロ除算を
SMT と同じ動作だとは扱わない。符号付き比較は同じビット列を `Int` / `Int64` に再解釈して行う。

配列のモデルで実行時のセルに対応するのは `[0, a.length())` の添字だけ。
モデルはその時点での配列内容を表し、破壊的更新をまたいで固定されたスナップショットではない。
可変長 `Array[T]` の対応や、一般的な store・更新範囲の契約はまだ含まない。

文字列アダプターは U+2FFFF 以下の Unicode スカラー値からなる正常な UTF-16 を受け付ける。
孤立サロゲートやそれより大きな文字は置換・正規化せず `None` を返す。
これは [SMT-LIB の文字集合](https://smt-lib.org/theories-UnicodeStrings.shtml) との共通部分。
`length`・`char_at`・`substring(start, count)` はコードポイント単位で、UTF-16 単位でも書記素単位でもない。
例えば `"A😀é".length()` は 4、アダプターの長さは 3、`char_at(1)` は `"😀"`。
範囲外の位置や非正の個数は空文字列になり、末尾を超える個数は切り詰める。
`runtime/text.Text` は実行時のラッパーで、証明専用の `strings.Text` とは別の型。
証明内の型変換やアダプター全体の正しさの定理はまだ提供しない。検索・置換・正規表現の実行時対応も今後の対象。

```moonbit
// mizchi/veri/runtime/uint32 と mizchi/veri/runtime/text を import する。
test {
  assert_eq(@uint32.add(0xffffffffU, 1U), 0U)
  let text = @text.from_string("A😀é").unwrap()
  assert_eq(text.length(), 3)
  assert_eq(text.substring(1, 2).to_string(), "😀é")
}
```

`examples/bridges` に別モジュールから契約付き関数を呼ぶ証明例がある。
加算が循環する場合も含め、両幅で `sub(add(value, delta), delta) == value` を証明する。
`just vectors` は FP と実行時の参照値を再生成し、`just vectors-check` は古い期待値を検出する。
`just verify` はオーバーフローや配列の要素を無視する誤実装が証明経路で拒否されることも確認し、
JS / wasm / wasm-gc / native の debug・release で実行時検査を行う。

### 証明の変換経路とパッケージの分離

`just prover-config` は、インストール済み Why3 の `z3_487.drv` から整数用ドライバを作り、
`_build/why3/` に出力する。native BV への変換を指定する import だけを除外し、
元の算術変換と BV 理論の公理を使う。同梱ファイルの書き換えや独自公理の追加は行わない。
生成した `MoonBit_Auto` は、ビット演算則には native bitvector、整数との対応には Why3 の整数モデルを
使えるよう、Z3 の両経路を維持する。さらに、前述の実数モデルと量化式用の経路を試す。
いずれも Why3 を信頼する境界内にある。
生成器は同梱ドライバの import 構成が想定と違う場合に失敗する。
検証条件を分割した後には Why3 の `compute_in_goal` を使い、構造的なモデルの
具体的なコンストラクターを簡約する。分割後に行うことで、リストの証明に必要な
再帰の仮定を残す。
`just prove` のパッケージ同時実行数は2に制限し、パッケージ増加による競合で
ソルバーの短い制限時間を使い切るのを抑える。

バインディングは `bitvector`、公開補題は `bitvector/laws`、
整数変換の補題は `bitvector/laws/integers` に分けた。
補題を呼び出す場合は対応するパッケージを import する。
無関係な補題を呼び出し元の証明へ持ち込まず、量化式の探索が増えるのを避ける。
`just prove` は両モジュールの全パッケージを検証する。
負例も同じ戦略の全経路を使い、無制限の整数を値を変えずに BV に写せるという主張や、
減算を加算だとする誤った契約が証明成功にならないことを確認する。

## IEEE 754 をどこまで検査できるか

**実行結果の検査**は、**各型 122 ケース**（境界などの指定入力 82 ケースと再現可能なサンプル 40 ケース）、
**Float ↔ Double の精度変換 62 ケース**を Z3 と照合する。各演算ケースでラッパーと組み込み式の両方を確認する。
対象は4演算、sqrt、符号反転、絶対値、IEEE の等値・順序比較、NaN・無限大の分類と、非 NaN のビット表現の往復。
丸めの中間点、subnormal、最小 normal、オーバーフロー、±0、±∞、NaN を含む。
期待値にはホストの浮動小数点演算を使わず、Z3 の FP 演算から生成する。全入力を列挙する検査ではない。

| 用途 | Float API | Double API |
| --- | --- | --- |
| ビット表現 | `@float32.from_bits(UInt)`・`to_bits(Float)` | `@float64.from_bits(UInt64)`・`to_bits(Double)` |
| 演算 | `add/sub/mul/div/sqrt/neg/abs` | 同じ名前 |
| 比較・分類 | `eq/less/is_nan/is_infinite` | 同じ名前 |
| 精度変換 | `@float32.to_double(Float)` | `@float64.to_float(Double)` |
| 参照値の比較 | `matches(value, Bits(UInt))` または `AnyNaN` | `matches(value, Bits(UInt64))` または `AnyNaN` |

```moonbit
// mizchi/veri/runtime/float32 と mizchi/veri/runtime/float64 を import する。
test {
  let one = @float32.from_bits(0x3f800000U)
  let half_ulp = @float32.from_bits(0x33800000U)
  assert_true(@float32.matches(@float32.add(one, half_ulp), Bits(0x3f800000U)))
  let wide = @float32.to_double(one)
  assert_true(@float64.matches(wide, Bits(0x3ff0000000000000UL)))
}
```

論理 API は `ieee754.Float64`・`ieee754/float32.Float32` と `ieee754/conversions.widen/narrow`。
両形式で `ieee754.RoundingMode` を共有する。変換の補題では RNE の binary32 → binary64 → binary32 が
符号付きゼロや抽象的な NaN の同一性を含めて元に戻ることを証明する。
逆方向の往復は有限の binary64 値でも精度を失い、`checks/fp32/narrowing-loss.smt2` に具体的な SAT の反例がある。
実行時の NaN ペイロード保存は保証しない。

**モデル上の形式検証**は、指定した前提を満たすすべてのモデル値について性質を証明する。
例えば「有限な x について x - x はゼロ」や「NaN の符号を反転しても NaN」。
加算の結合則のように成立しない性質も、具体的な反例を示せる。

```text
a = 2^53, b = -2^53, c = 0.5, 丸めは RNE

(a + b) + c = 0.5
a + (b + c) = 0.0
```

この反例は SMT と MoonBit の両方で再現する。

**実際の Float / Double 演算との接続には、コンパイラ側の対応が必要。**
確認したツールチェインでは契約付き関数の本体に FP 算術を置くと
`unsupported primitive operator in contracted function body` になり、論理内の比較も未対応。
`just fp-capabilities` で新しい一時モジュール内に再現し、`_build/fp-capabilities.json` に対応状況を記録する。
これはコンパイラの変換能力を調べる検査であり、IEEE の正しさの証明とは別。
将来変換が通るようになっても、生成される IEEE 型・丸め規則を確認し、対応を証明する必要がある。
そのため実行時 FP API には証明契約や、仮定による `model(Float/Double)` 変換を付けていない。
Why3 モデル上の証明と実行時の差分検査を用意し、その両者を結ぶ全入力の定理は今後の対象とする。

## 信頼する境界と未対応

- `#proof_external` / `#proof_import` の型・引数順・Why3 記号の対応、Why3、ソルバー、MoonBit の変換処理を信頼する。独自の `proof_axiomatized` は使わない。
- 通常の整数証明は数学的整数モデル。bounds・循環演算・FixedArray の読み取りと更新・コレクション・利用例は同梱の機械整数モデルでも別途証明する。`clamp` の `min <= max` と `clamp_half_open` の `lower < upper` は呼び出し側の事前条件であり、実行時の入力検査ではない。
- 実行時の検査プロファイルは binary32・binary64 の RNE。論理 API は 5 丸めモードを持つが、実行時に全モードを設定・検査する機能はない。
- NaN ペイロード、signaling / quiet NaN、例外フラグ、trap、decimal、実行時 FMA、浮動小数点の文字列変換は未検査。SMT-LIB の FP 理論自体も signaling / quiet NaN を区別しない。
- 超越関数の `sin` / `exp` などや、実数アルゴリズムに対する誤差上限の証明は別途必要。
- `unknown` / timeout は未証明。真偽の結論にはしない。SMT の正例チェックは期待した `unsat` 以外で失敗する。負例チェックは偽命題が未証明になることを確認するだけで、ソルバーが反例を出したとは主張しない。
- 依存パッケージを仮定する対象指定の証明だけに頼らず、`just prove` で workspace の両モジュールを証明する。
- 現在はローカルツールチェインを利用する。共有 CI のための配布物・ソルバーのバージョン固定は今後の課題。

次はコンパイラの実演算 FP 証明変換、Berkeley TestFloat / SoftFloat のケース取り込み、bitvector の切り出し・符号拡張、
実行時のブリッジ契約の拡充、正規表現、実行時の有限 Map を拡張できる。
TestFloat / SoftFloat はこのリポジトリにはまだ組み込んでいない。

## 参考

- [MoonBit Formal Verification](https://docs.moonbitlang.com/en/latest/language/verification.html): 契約、外部理論、信頼モデル。
- [moonbit-community/verified の FSet](https://github.com/moonbit-community/verified/tree/main/libs/fset): 有限集合を取り込む設計の参考。本リポジトリは小さな接続 API と利用例を独自に用意している。
- [MoonBit の形式検証を活用した実例](https://eng.mates.education/blog/b-moonbit-formal-verification/): 整数の契約、実行時との差、浮動小数点の差分検査。
- [Why3 ieee_float](https://www.why3.org/stdlib/ieee_float.html): IEEE の論理型と演算。
- [Why3 標準ライブラリ](https://www.why3.org/stdlib/): Seq・List・Bag・有限 Map・Tree・Stack・Queue・PQueue の仕様。利用可能な理論は同梱ファイルを基準とする。
- [SMT-LIB FloatingPoint](https://smt-lib.org/theories-FloatingPoint.shtml): IEEE FP 演算、丸めモード、NaN 表現の範囲。
- [Berkeley TestFloat](https://www.jhauser.us/arithmetic/TestFloat.html) / [SoftFloat](https://www.jhauser.us/arithmetic/SoftFloat.html): 演算の適合検査とソフトウェア参照実装。

- [Z3 Guide: Bitvectors](https://microsoft.github.io/z3guide/docs/theories/Bitvectors/): 固定幅、signed/unsigned 演算、剰余算術。
- [Z3 Guide: Arrays](https://microsoft.github.io/z3guide/docs/theories/Arrays/): select/store と外延的な配列。
- [Z3 Guide: Strings](https://microsoft.github.io/z3guide/docs/theories/Strings/): 文字列演算と Unicode の意味論。

## ライセンス

[Apache-2.0](LICENSE)。
