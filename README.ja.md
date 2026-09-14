# veri

[English](README.md) | 日本語

MoonBit の形式検証を使うための小さな基盤。再利用する論理モデル・補題、契約付き実装、実行時の差分検査を用意する。

IEEE 754 の性質を検証する道具は作れる。ここではまず **binary64 / roundTiesToEven (RNE)** の実行結果を検査し、Why3 の IEEE モデル上の性質を証明する。規格全体への適合認証や、MoonBit コンパイラ・CPU の正しさの証明を提供するものではない。

## 実行

必要なものは MoonBit、`~/.moon/share/why3/` の同梱 Why3 データ、PATH 上の Z3、Node.js 24+、just。Node スクリプトに外部依存はない。

```sh
just doctor       # バージョンと同梱 Why3 の存在を確認
just verify       # 形式検証、負例、参照値、各バックエンドのテスト
```

個別に実行する場合:

```sh
just prove        # MoonBit → Why3 → SMT。モジュール全体の証明
just prove-machine # 同梱の機械整数 prelude で bounds の契約を証明
just smt          # IEEE FP 理論による UNSAT 証明と SAT の具体的反例
just negative     # 意図的な偽命題が証明成功にならないことを確認
just test js      # 実行時検査
just test-backends # JS / wasm / wasm-gc / native
just test-release # 最適化したビルドでも同じ検査
just vectors      # Z3 から期待値を再生成
just vectors-check # 生成済み期待値と現在の Z3 の結果を照合
just fmt          # フォーマット・公開インターフェース生成
```

手元で確認した環境は moon 0.1.20260904、moonc v0.10.12+1634b282e、Z3 4.16.0。
このツールチェインの `moon prove` は `~/.moon/share/why3` を自動で利用する。別の Why3 インストールは行わない。
実際に選択したパスとソルバーは `_build/verif/why3.conf`、証明結果はその配下の `*.proof.json` に出力される。

## 構成と保証

| パス | 内容 | 確認すること |
| --- | --- | --- |
| `libs/bounds` | 半開区間への clamp | 有効な上下限に対し結果が区間内に入り、元から区間内の値を保存する |
| `libs/fset` | Why3 の有限集合への接続 | 空集合・要素追加・和集合の補題 |
| `libs/ieee754` | 論理上の binary64 と丸めモード | NaN、符号付きゼロ、有限値の自己減算などの補題 |
| `examples/models` | ライブラリを import する利用例 | 別パッケージから集合・IEEE モデルを使えること |
| `runtime/float64` | 実行結果の比較と参照ケース | 4 演算と sqrt の結果を Z3 の IEEE FP 理論と照合 |
| `checks/fp` | SMT-LIB の小さな仕様検査 | 全入力に対する性質と、固定入力の反例 |
| `checks/negative` | 意図的に誤った補題 | 誤った主張を検証経路が成功扱いしないこと |

`.mbt` が実装・型・契約、`.mbtp` が論理モデル・補題。`pkg.generated.mbti` で公開 API を確認できる。
`libs/fset` と `libs/ieee754` の抽象型は **証明専用**。実行時の集合や `Double` ではない。

最小の利用例:

```moonbit
// moon.pkg で mizchi/veri/libs/ieee754 を import し、proof-enabled を有効にする。
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

## IEEE 754 をどこまで検査できるか

**実行結果の検査**は、境界入力と再現可能なサンプルについて期待値との一致を確認する。
現在は 46 境界ケースと 40 サンプルの計 86 ケース。丸めの中間点、subnormal、最小 normal、
オーバーフロー、±0、±∞、NaN、sqrt を含む。入力はビット列で指定し、期待値にはホストの
JavaScript 浮動小数点演算を使わず、Z3 の FP 演算から生成する。
全入力を列挙する検査ではない。

**モデル上の形式検証**は、指定した前提を満たすすべてのモデル値について性質を証明する。
例えば「有限な x について x - x はゼロ」や「NaN の符号を反転しても NaN」。
加算の結合則のように成立しない性質も、具体的な反例を示せる。

```text
a = 2^53, b = -2^53, c = 0.5, 丸めは RNE

(a + b) + c = 0.5
a + (b + c) = 0.0
```

この反例は SMT と MoonBit の両方で再現する。

**実際の MoonBit Double 演算との接続**には追加の仕事が必要。
確認したツールチェインでは Double 比較を直接 proof_ensure に置くと
`unsupported primitive operator in logic body` になる。
FSet と同じ `#proof_external` / `#proof_import` により IEEE モデルを利用できるが、
これだけで MoonBit の実演算とモデルが等しいと証明したことにはならない。
現段階ではその間を差分テストで検査する。

## 信頼する境界と未対応

- `#proof_external` / `#proof_import` の型・引数順・Why3 記号の対応、Why3、ソルバー、MoonBit の変換処理を信頼する。独自の `proof_axiomatized` は使わない。
- 通常の整数証明は数学的整数モデル。bounds は同梱の機械整数モデルでも別途証明する。`lower < upper` は呼び出し側の事前条件であり、実行時の入力検査ではない。
- 実行時の検査プロファイルは binary64 の RNE。論理 API は 5 丸めモードを持つが、実行時に全モードを設定・検査する機能はない。
- NaN ペイロード、signaling / quiet NaN、例外フラグ、trap、decimal、binary32、実行時 FMA、文字列変換は未検査。SMT-LIB の FP 理論自体も signaling / quiet NaN を区別しない。
- 超越関数の `sin` / `exp` などや、実数アルゴリズムに対する誤差上限の証明は別途必要。
- `unknown` / timeout は未証明。真偽の結論にはしない。SMT の正例チェックは期待した `unsat` 以外で失敗する。負例チェックは偽命題が未証明になることを確認するだけで、ソルバーが反例を出したとは主張しない。
- 依存パッケージを仮定する対象指定の証明だけに頼らず、`just prove` でモジュール全体を証明する。
- 現在はローカルツールチェインを利用する。共有 CI のための配布物・ソルバーのバージョン固定は今後の課題。

次は binary32、Berkeley TestFloat / SoftFloat のケース取り込み、ビットベクトル表現の検証、
実装とモデルを結ぶ契約、集合以外の Seq / Map モデルを順に拡張できる。
TestFloat / SoftFloat はこのリポジトリにはまだ組み込んでいない。

## 参考

- [MoonBit Formal Verification](https://docs.moonbitlang.com/en/latest/language/verification.html): 契約、外部理論、信頼モデル。
- [moonbit-community/verified の FSet](https://github.com/moonbit-community/verified/tree/main/libs/fset): 有限集合を取り込む設計の参考。本リポジトリは小さな接続 API と利用例を独自に用意している。
- [MoonBit の形式検証を活用した実例](https://eng.mates.education/blog/b-moonbit-formal-verification/): 整数の契約、実行時との差、浮動小数点の差分検査。
- [Why3 ieee_float](https://www.why3.org/stdlib/ieee_float.html): IEEE の論理型と演算。
- [SMT-LIB FloatingPoint](https://smt-lib.org/theories-FloatingPoint.shtml): IEEE FP 演算、丸めモード、NaN 表現の範囲。
- [Berkeley TestFloat](https://www.jhauser.us/arithmetic/TestFloat.html) / [SoftFloat](https://www.jhauser.us/arithmetic/SoftFloat.html): 演算の適合検査とソフトウェア参照実装。
