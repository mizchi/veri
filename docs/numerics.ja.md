# Bitvector・順序・数値モデル

[English](numerics.md) | [README](../README.ja.md)

## Bitvector API

`moon.pkg` で `"mizchi/veri/bitvector"` を import すると4種類の幅を使える。`.mbt` ファイルで型を取り込む:

```moonbit
using @bitvector {type Bv8, type Bv16, type Bv32, type Bv64}
```

`.mbtp` の証明と実行時の契約では `Bv32::add(x, y)`、`Bv64::add(x, y)`、`Bv32::of_integer(n)` などの型メソッドを使う。型はそれぞれ Why3 の `bv.BV8` / `bv.BV16` / `bv.BV32` / `bv.BV64` に対応する。現在の `.mbtp` パーサでは、別パッケージの型メソッドを呼ぶためにこの `using` が必要。従来の幅別パッケージと自由関数から、この API に置き換えた。

公開補題は幅を末尾につけ、`bitvector/laws` の `@laws.addition_wraps32()` / `addition_wraps64()`、`bitvector/laws/integers` の `integer_roundtrip32` / `integer_roundtrip64` として提供する。整数変換の補題は別パッケージに保ち、量化式の探索を抑える。`examples/bitvector/widths.mbtp` では、1つのパッケージの import で、2^32 が Bv32 ではゼロに循環し、Bv64 では保持されることを証明する。これらの補題と利用例は `just prove-machine` でも検証する。

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
