# 証明の仕組みと実行時型との対応

[English](architecture.md) | [README](../README.ja.md)

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
| `FixedArray[T]` | `@runtime_array.model(a)` → `SmtArray[Integer, T]` と `a.length()` | 読み取り・範囲検査・更新の契約を両モデルで証明。更新前後の証明範囲は[配列の更新](collections.ja.md#fixedarray-の更新と範囲操作)を参照 |
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
使えるよう、Z3 の両経路を維持する。さらに、[数値モデル](numerics.ja.md#順序整数論実数と誤差評価)で説明した実数モデルと量化式用の経路を試す。
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
