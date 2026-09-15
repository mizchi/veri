# veri

[English](README.md) | 日本語

MoonBit の形式検証を使うための小さな基盤。再利用する論理モデル・補題、契約付き実装、実行時の差分検査を用意する。

## QuickStart

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

この最小例の証明には同梱 Why3 と PATH 上の Z3 を使う。

## ドキュメント

| 文書 | 内容 |
| --- | --- |
| [パッケージ一覧](docs/packages.ja.md) | 提供するモデル・API と保証範囲 |
| [実行時 API・グラフ検査](docs/toolkit.ja.md) | Map / Set、探索、整数演算、codec、Union-Find、パーサ、経路・トポロジー検査 |
| [コレクション・配列](docs/collections.ja.md) | List、Stack、Queue、優先キュー、木、FixedArray の更新と契約 |
| [Bitvector・数値モデル](docs/numerics.ja.md) | 固定幅ビット列、順序、整数論、実数、丸め誤差 |
| [検証手順](docs/verification.ja.md) | ソルバーの設定、moon prove、QuickCheck と shrinking |
| [ベンチマーク](docs/benchmarks.ja.md) | core との比較方法、計測条件、チューニング結果 |
| [証明の仕組み](docs/architecture.ja.md) | Why3 / SMT-LIB との接続、実行時型との対応、信頼する境界 |
| [IEEE 754](docs/floating-point.ja.md) | Float / Double の API、参照検査、証明範囲と未対応機能 |
| [時相論理のモデル検査](docs/temporal.ja.md) | moonx、Z3 / Apalache、TaskGroup・lease-clock の例 |
| [実用ワークフロー](docs/model-workflows.ja.md) | CI スイート、反例の保存、モデル構築、実装との比較 |

## ライセンス

[Apache-2.0](LICENSE)。
