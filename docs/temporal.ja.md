# 時相論理のモデル検査

[English](temporal.md) | [README](../README.ja.md)

## 時相論理の検査実験

`just temporal` は固定のジョブモデルを Z3 で検査する。帰納的な安全性、永久に待機する
活性の反例、弱公平性を含む検査と要求を失う反例を用意した。有限長のループ検査は
「指定の上限で反例なし」と報告し、無限実行に対する時相性質の証明と区別する。
SAT の実行列は独立した有限状態モデルでも再生する。
[実験の説明](../checks/temporal/README.ja.md)を参照。
`just verify-temporal` では共用する MoonBit の遷移と任意長の有限実行列の安全性も証明し、
実際の遷移表を Z3 に渡して反例を MoonBit で再生する。汎用の公開時相APIではなく、開発用PoCである。

`just verify-task-group` は、子2個と本体からなる TaskGroup のモデルを検査する。
`no_wait`・`allow_failure`・キャンセル・終了待ち・グループの後始末を扱い、
`moon prove`、Z3 の応答性検査、shrinking 付き QuickCheck、本物の `moonbitlang/async@0.21.3`
の実行履歴との照合を行う。実ランタイムとの対応はテストの対象で、未証明。
[TaskGroup の使い方と保証範囲](../checks/task_group/README.ja.md)を参照。

`just apalache` は Nix で Apalache 0.62.2 と Java 21 を用意し、Job・TaskGroup の
計15検査を深さ8まで Z3 と照合して、反例を MoonBit で再生する。
ログ・生成した TLA+・ITF の反例は `_build/apalache` 以下に保存する。
有限モデルを扱う任意のバックエンドで、上限内での反例なしを無制限の活性証明とは扱わない。

`just verify-lease-clock` は [Quint の lease-clock モデルの移植例](../examples/lease_clock/README.ja.md)を検査する。
4操作の二重 writer の反例を再現し、修正した有限モデルの470状態を全探索する。
`just apalache-lease-clock` で上限付きの検査を Apalache とも照合できる。
プロトコルのモデルのみを扱う例。

3つのモデルは [共通の client / driver](../model_check/README.ja.md) を使う。
MoonBit の `Client`・`serve` で新しいモデルを接続し、`moonx veri.mbtx` から
export・Z3 検査・反例再生を実行できる。CLI の実行に Node.js は不要。
例えば `moonx veri.mbtx check lease_clock/driver --module examples --config '{"variant":0,"bound":8}' --safety single_writer --bound 8`。
`just verify-model-check` で共通 API と既存モデルを検査する。

[実用ワークフロー](model-workflows.ja.md): スイート、反例、モデル構築、デッドロック、実装との比較。
