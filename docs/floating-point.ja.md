# IEEE 754 の検証

[English](floating-point.md) | [README](../README.ja.md)

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
