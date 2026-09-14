# veri

[English](README.md) | 日本語

MoonBit の形式検証を使うための小さな基盤。再利用する論理モデル・補題、契約付き実装、実行時の差分検査を用意する。

有限集合・固定幅 bitvector・全域 array・string・IEEE 浮動小数点の証明用バインディングを提供する。IEEE 754 については **binary32・binary64 / roundTiesToEven (RNE)** の実行結果を検査し、Why3 の IEEE モデル上の性質を証明する。規格全体への適合認証や、MoonBit コンパイラ・CPU の正しさの証明を提供するものではない。

## 実行

必要なものは MoonBit、`~/.moon/share/why3/` の同梱 Why3 データ、PATH 上の Z3、Node.js 24+、just。Node スクリプトに外部依存はない。

```sh
just doctor       # バージョンと同梱 Why3 の存在を確認
just verify       # 形式検証、負例、参照値、各バックエンドのテスト
```

個別に実行する場合:

```sh
just prove        # MoonBit → Why3 → SMT。workspace の両モジュールを証明
just prove-machine # 機械整数 prelude で bounds・実行時ブリッジ・利用例を証明
just smt          # FP・bitvector・array・string の UNSAT 証明と SAT の反例
just negative     # 各モデルで意図的な偽命題が証明成功にならないことを確認
just test js      # 実行時検査
just quickcheck js # QuickCheck の性質テストだけを実行
just test-backends # JS / wasm / wasm-gc / native
just test-release # 最適化したビルドでも同じ検査
just fp-capabilities # Float/Double の証明変換の対応状況を確認
just vectors      # Z3 から期待値を再生成
just vectors-check # 生成済み期待値と現在の Z3 の結果を照合
just fmt          # フォーマット・公開インターフェース生成
```

手元で確認した環境は moon 0.1.20260904、moonc v0.10.12+1634b282e、Z3 4.16.0。
このツールチェインの `moon prove` は `~/.moon/share/why3` を自動で利用する。別の Why3 インストールは行わない。
`just` の証明レシピは、native BV と整数モデルの2経路を登録した `_build/why3/why3.conf` を生成する。
証明結果は各モジュールの `_build/verif/` 配下の `*.proof.json` に出力される。
`just prove` を使う。`moon prove` 単体の既定の変換経路では、整数と BV の対応証明が時間切れになる場合がある。

## 構成と保証

| パス | 内容 | 確認すること |
| --- | --- | --- |
| `bounds` | 半開区間への clamp | 有効な上下限に対し結果が区間内に入り、元から区間内の値を保存する |
| `fset` | Why3 の有限集合への接続 | 空集合・要素追加・和集合の補題 |
| `ieee754` / `ieee754/float32` | 論理上の binary64 / binary32 と共通の丸めモード | NaN、符号付きゼロ、有限値の自己減算などの補題 |
| `ieee754/conversions` | 論理上の拡幅・縮幅 | binary32 の拡幅往復と NaN 分類の保存 |
| `bv32` / `bv64` | Why3 の固定幅 bitvector への接続 | 各演算と、剰余を取る整数変換 |
| `bv32/laws` / `bv64/laws` | bitvector の補題。整数の補題は `laws/integers` | ビット演算則、双方向の変換、符号なし数値の範囲 |
| `arrays` | select/store を持つ全域写像 | 更新後の読み出し、別キーの保存、最後の更新の優先 |
| `strings` | 論理上の SMT string | 連結、長さ、部分文字列、検索、置換 |
| `examples/models` | ライブラリを import する利用例 | 別モジュールでの証明と、bitvector をキー・string を値に持つ array |
| `integer` | 数学的整数と実行時の値の射影 | Int / UInt / Int64 / UInt64 の契約で共用する型 |
| `runtime/uint32` / `runtime/uint64` | 循環加減算の実装 | 両整数モデルで add/sub/less の BV との一致を直接証明し、Z3 参照値とも照合 |
| `runtime/array` | FixedArray のモデルと安全な読み取り | 境界検査とモデル内の要素との一致 |
| `runtime/text` | 検証済み入力を持つ SMT 互換文字列 | コードポイント単位の長さ・char_at・substring を Z3 と照合 |
| `examples/bridges` | 実行時ブリッジの利用例 | 別モジュールから契約を組み合わせた証明 |
| `runtime/float32` / `runtime/float64` | 実行時 FP API と参照値比較 | 算術・sqrt・neg/abs・比較・分類・非 NaN のビット往復を照合 |
| `runtime/float_conversions` | 精度変換の検査 | Float ↔ Double を丸め境界を含めて Z3 と照合 |
| `examples/floating` | 実行時 FP の利用例 | Float と Double での丸め精度の違い |
| `checks/` | FP・bitvector・array・string の SMT-LIB 2 検査 | 全入力に対する性質と、固定入力の反例 |
| `checks/negative` | 意図的に誤った補題 | 誤った主張を検証経路が成功扱いしないこと |

ルートがライブラリ本体の `mizchi/veri`、`examples/` がそれに依存する独立モジュール
`mizchi/veri-examples`。`moon.work` に両方を登録する。

```text
veri/
├── moon.mod                 # mizchi/veri
├── moon.work                # members: ".", "examples"
├── bounds/
├── bv32/
├── bv64/
├── arrays/
├── strings/
├── fset/
├── ieee754/
├── integer/
├── runtime/                 # uint32, uint64, array, text, float32, float64, float_conversions
└── examples/
    ├── moon.mod             # mizchi/veri-examples; mizchi/veri@0.1.0 に依存
    ├── models/
    ├── bridges/
    └── floating/
```

workspace 内の依存はローカルの本体へ解決され、レジストリから取得しない。
公開パッケージは `mizchi/veri/bounds`、`mizchi/veri/bv32`、`mizchi/veri/arrays` などのパスで import する。
本体と examples の証明は `just prove` でまとめて実行する。このツールチェインでは
`moon prove` 単体は現在のモジュールが対象で、examples の証明には `moon -C examples prove` を使う。
証明結果は各モジュールの `_build/verif/` 配下に出力される。

`.mbt` が実装・型・契約、`.mbtp` が論理モデル・補題。`pkg.generated.mbti` で公開 API を確認できる。
`fset`・`ieee754`・`ieee754/float32`・`bv32`・`bv64`・`arrays`・`strings` の抽象型は **証明専用**。バインディングだけで MoonBit の実行時の値との対応が保証されるわけではない。

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

## QuickCheck による性質テスト

`moonbitlang/core/quickcheck` をテスト専用で import する。
`bounds/properties_test.mbt` と `runtime/*/properties_test.mbt` の26個の性質を、
固定 seed `20260914` でそれぞれ1,000件の有効入力に対して検査する。
コレクションの生成サイズは最大64。`just quickcheck js`（または `wasm`、
`wasm-gc`、`native`）で実行でき、`just test`・`just test-backends`・
`just test-release`・`just verify` にも含まれる。

検査対象は clamp の範囲と単調性、整数の循環演算と順序、配列の読み取りと更新、
SMT の文字集合とコードポイント単位の位置、浮動小数点のビット表現・分類・
符号操作・演算の恒等則・精度変換の往復。
文字列の操作はスカラー値を順番に走査する独立の参照処理と照合する。
浮動小数点は `UInt` / `UInt64` のビット列から生成し、特殊値と指数の全範囲を
生成対象にする。非 NaN はゼロの符号も含めて比較し、NaN は分類だけを比較する。
NaN ペイロードの保存は要求しない。

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

## バインディングの接続先

MoonBit 側の API は **Why3 の理論**に接続する。Why3 のソルバードライバが、対応する演算を SMT-LIB 2 に変換する。

```text
MoonBit の契約 / .mbtp → Why3 の理論 → SMT-LIB 2 → Z3
checks/**/*.smt2 ──────────────────→ SMT-LIB 2 → Z3
```

`#proof_external` が論理型、`#proof_import` が論理演算の対応を定義する。
`.smt2` の検査は MoonBit / Why3 を経由しない別経路。
これらは証明用 API であり、実行時に Z3 を呼ぶ FFI や汎用 SMT-LIB 2 式ビルダーではない。

| パッケージ | Why3 の理論 | 主な演算 |
| --- | --- | --- |
| `bv32` / `bv64` | `bv.BV32` / `bv.BV64` | `add/sub/mul`、`udiv/urem`、`sdiv/srem`、`bw_and/or/xor/not`、`shl/lshr/ashr`、`ult/ule/slt/sle` |
| `arrays` | `map.Map`、`map.Const` | `select`、`store`、`const_array`、外延的な `eq` |
| `strings` | `string.String` | `concat`、`length`、`char_at`、`substring`、`contains`、`prefix_of`、`suffix_of`、`index_of`、`replace`、`to_int/from_int`、`lt/le` |

bitvector は固定幅で、初版は 32 / 64 bit を提供する。signed / unsigned はビット列の型ではなく演算で区別し、
加減乗算は 2^width を法として循環する。シフト量も同じ幅の bitvector で、幅以上のシフト量を剰余で折り返さない。
`width()` は 32 または 64 を表す bitvector。SMT モデルでは `udiv(x, zero())` は全ビット1になるが、
実行時の除算についての保証ではない。任意幅、切り出し、拡張はまだ公開していない。
`of_integer` は最初に 2^width で剰余を取り、負数や幅を超える数学的整数も変換できる。
`to_integer` は符号なし数値、`modulus()` は 2^width を返し、`in_range` は符号なしの範囲を判定する。
`to_integer(of_integer(n)) = n mod 2^width` と `of_integer(to_integer(v)) = v` を補題で証明する。

`SmtArray[K, V]` はすべてのキーに値を持つ全域写像で、長さ・境界検査・破壊的更新はない。
`store` は新しい写像を返す。メモリのモデルには使えるが、実行時の配列の境界や動作をそれだけで証明するものではない。

`Text` は U+0000..U+2FFFF を文字集合とする SMT の文字列モデル。
長さはコードポイント数なので、この範囲内の補助平面の文字も1であり、
MoonBit の実行時の UTF-16 長とは異なる。`char_at` の返り値は文字列、`substring` の引数は開始位置と個数。
不正な位置は空文字列、検索失敗は -1 となり、`replace` は最初の一致を置換する。
`to_int/from_int` は SMT の非負整数の10進変換規則に従い、その `Int` は既定の数学的整数モデルで扱う。
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
| `FixedArray[T]` | `@runtime_array.model(a)` → `SmtArray[Integer, T]` と `a.length()` | `get` が範囲内でモデルの要素を Some で返し、範囲外では None を返すことを両モデルで証明 |
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
使えるよう、Z3 の両経路を試す。どちらも Why3 を信頼する境界内にある。
生成器は同梱ドライバの import 構成が想定と違う場合に失敗する。

バインディングは `bv32` / `bv64`、公開補題は `bv32/laws` / `bv64/laws`、
整数変換の補題は `bv32/laws/integers` / `bv64/laws/integers` に分けた。
補題を呼び出す場合は対応するパッケージを import する。
無関係な補題を呼び出し元の証明へ持ち込まず、量化式の探索が増えるのを避ける。
`just prove` は両モジュールの全パッケージを検証する。
負例も同じ2経路を使い、無制限の整数を値を変えずに BV に写せるという主張や、
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
- 通常の整数証明は数学的整数モデル。bounds・循環演算・FixedArray の読み取り・ブリッジの利用例は同梱の機械整数モデルでも別途証明する。`lower < upper` は呼び出し側の事前条件であり、実行時の入力検査ではない。
- 実行時の検査プロファイルは binary32・binary64 の RNE。論理 API は 5 丸めモードを持つが、実行時に全モードを設定・検査する機能はない。
- NaN ペイロード、signaling / quiet NaN、例外フラグ、trap、decimal、実行時 FMA、浮動小数点の文字列変換は未検査。SMT-LIB の FP 理論自体も signaling / quiet NaN を区別しない。
- 超越関数の `sin` / `exp` などや、実数アルゴリズムに対する誤差上限の証明は別途必要。
- `unknown` / timeout は未証明。真偽の結論にはしない。SMT の正例チェックは期待した `unsat` 以外で失敗する。負例チェックは偽命題が未証明になることを確認するだけで、ソルバーが反例を出したとは主張しない。
- 依存パッケージを仮定する対象指定の証明だけに頼らず、`just prove` で workspace の両モジュールを証明する。
- 現在はローカルツールチェインを利用する。共有 CI のための配布物・ソルバーのバージョン固定は今後の課題。

次はコンパイラの実演算 FP 証明変換、Berkeley TestFloat / SoftFloat のケース取り込み、bitvector の切り出し・拡張、
実行時のブリッジ契約の拡充、正規表現、Seq / 有限 Map のモデルを拡張できる。
TestFloat / SoftFloat はこのリポジトリにはまだ組み込んでいない。

## 参考

- [MoonBit Formal Verification](https://docs.moonbitlang.com/en/latest/language/verification.html): 契約、外部理論、信頼モデル。
- [moonbit-community/verified の FSet](https://github.com/moonbit-community/verified/tree/main/libs/fset): 有限集合を取り込む設計の参考。本リポジトリは小さな接続 API と利用例を独自に用意している。
- [MoonBit の形式検証を活用した実例](https://eng.mates.education/blog/b-moonbit-formal-verification/): 整数の契約、実行時との差、浮動小数点の差分検査。
- [Why3 ieee_float](https://www.why3.org/stdlib/ieee_float.html): IEEE の論理型と演算。
- [SMT-LIB FloatingPoint](https://smt-lib.org/theories-FloatingPoint.shtml): IEEE FP 演算、丸めモード、NaN 表現の範囲。
- [Berkeley TestFloat](https://www.jhauser.us/arithmetic/TestFloat.html) / [SoftFloat](https://www.jhauser.us/arithmetic/SoftFloat.html): 演算の適合検査とソフトウェア参照実装。

- [Z3 Guide: Bitvectors](https://microsoft.github.io/z3guide/docs/theories/Bitvectors/): 固定幅、signed/unsigned 演算、剰余算術。
- [Z3 Guide: Arrays](https://microsoft.github.io/z3guide/docs/theories/Arrays/): select/store と外延的な配列。
- [Z3 Guide: Strings](https://microsoft.github.io/z3guide/docs/theories/Strings/): 文字列演算と Unicode の意味論。
