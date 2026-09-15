# モデル検査の実用ワークフロー

[English](model-workflows.md) | [README](../README.ja.md)

## CI の検査スイート

checkout のルートで `just model-suite`、任意の設定では次を実行する。

```sh
moonx veri.mbtx test checks/model_check/suite.json
```

スイートは `{ "version": 1, "cases": [...] }`。各ケースには `name`、`driver`、
`property`、`expect` を指定する。`module_dir` はスイートファイルの場所からの相対パスで、
省略時はそのディレクトリ。`config` は既定 `{}`、`target` は `wasm`、`bound` は8。
`fair: true` または `justice: [1]` で弱公平性を指定する。両方の同時指定は拒否する。

上限付き検査の `expect` は `counterexample`、`witness`、`no-counterexample-up-to-bound`、
`unreachable-up-to-bound` のいずれか。全検査の結果名は後述する。
性質と矛盾する期待結果や重複したケース名を拒否する。
反例を期待するケースも成功にできるため、故障を注入したモデルを回帰検査に含められる。
全ケースの結果を JSON にまとめ、期待がすべて一致した場合だけ終了コード0を返す。
`unknown`、タイムアウト、再生拒否、起動失敗はエラーであり、期待結果には指定できない。
ケースが失敗しても残りを実行する。スイート自体が不正なら検査開始前に失敗する。

既存の `check` は引き続き問い合わせとして動き、反例が見つかっても終了コード0。
上限付きの検査成功を、無制限の証明とは扱わない。

## 反例の保存と説明

```sh
moonx veri.mbtx check lease_clock/driver --module examples \
  --config '{"variant":0,"bound":4}' --safety single_writer --bound 4 --save trace.json
moonx veri.mbtx explain trace.json
moonx veri.mbtx replay-file trace.json
```

`--save` は設定・性質・公平性・有限モデル全体・結果を version 1 の bundle として保存する。
`explain` はイベント名と JSON pointer ごとの変更前後を返し、安全性の違反位置、
応答性のループ開始位置も表示する。保存時のモデルに対して証明書を検査してから説明する。
`replay-file` は現在のモデル全体との一致と、実際の `step` / `holds` による再生を要求する。
他の checkout では `--module DIR` でモデルの場所を指定できる。実行ファイルの同一性を
保証するものではなく、モデルの同一性と実際の再生を検査する。入力は信頼する自分の bundle を使う。
反例のない結果も保存できるが、証明書のない bundle は explain / replay-file の対象外。
`--complete --save FILE` も使用でき、bundle に `complete: true` を記録する。
このフィールドのない既存の version 1 bundle は、上限付き検査として引き続き再生できる。
全検査ではソルバー用 `limits` は使用しない。

`model_check.minimize` は入力・設定に対する汎用の縮小器。候補生成、非負の複雑度、
失敗を再現する述語を渡す。複雑度が厳密に小さく、失敗が残る候補だけを採用し、
試行上限で停止する。core の `Shrink::shrink` と組み合わせられる。述語は試行ごとに
新しい状態で再生すること。局所的な縮小であり、全候補中の最小性は主張しない。

## 名前付きのモデル定義

`model_check.Spec[State, Event, Snapshot]` に `initial`、`actions`（名前とイベントの組）、
`step`、`predicates`（名前と判定関数の組）、`snapshot`、`justice`（イベント名）を渡す。
`build_client(spec, max_depth=..., max_states=...)` が探索・遷移表・述語表・再生用 Client を
生成する。述語とイベントを一度だけ定義でき、重複名や未知の公平性名を拒否する。
状態は不変で、`Eq` は全状態を比較し、callback は決定的であることが前提。
スナップショットは表示専用で、状態同一性には使用しない。

状態 ID を既存の証明と合わせる場合は `client_from_states(spec, states)` を使う。
全イベントに対して閉じた、重複のない状態領域を要求する。深さ上限で省略した遷移は
`build_client` が `exploration` に記録するため、完全探索と混同しない。
3つの既存モデルの explorer が具体例になる。

## デッドロックと応答性の前提

`check ... --deadlock terminal` は、`terminal` が偽で、実行可能なイベントが1つもない
到達状態を探す。正常終了状態を除外し、実行可能な自己ループは遷移として数える。
自己ループだけで進展しない問題は、応答性と公平性で検査する。
深さで切った frontier を、遷移のない状態と誤認しない。反例は実際の全イベントを再実行して確認する。
スイートの性質は `{ "kind": "deadlock", "terminal": "terminal" }`。

`--response pending done --require-trigger` は、同じ深さ以内に `pending` が真の状態へ
到達できることも要求する。到達しなければ `TriggerUnreachable` エラーになる。
スイートでは `require_trigger: true`。これは指定上限内の前提の到達性の確認であり、
すべての実行で要求が発生するという保証ではない。
`--complete` との併用では有限モデル全体の到達性を調べ、到達できなければ
`TriggerUnreachableInCompleteModel` エラーを返す。

## 探索規模と資源上限

`explore` / `build_client` は `state_hash=state => state.hash()` を指定するとハッシュ索引を使う。
ハッシュ衝突は `Eq` で解決する。同値な状態は同じハッシュになることが必要。
省略時は従来の Eq による線形検索。`max_states`（既定4,096）と `max_transitions`
（無効な遷移も含む表のセル数、既定4,000,000）で探索量を制限し、超過時はエラーを返す。
探索深さと SMT の深さは最大1,000,000まで指定できるが、実用的な上限はモデルと予算による。

CLI は1性質につき1つの Z3 プロセスで、遷移を追加しながら push/pop で検査する。
`--timeout-ms` は1ソルバーセッション全体の上限（既定60,000）、`--memory-mb` は
Z3 のメモリ上限（既定512）。`--max-query-bytes` と `--max-output-bytes` は
そのセッションの送受信総量（それぞれ既定16 MiB）。スイートでは同名のフィールドを持つ
`limits` オブジェクト（`timeout_ms`、`memory_mb`、`max_query_bytes`、`max_output_bytes`）で指定する。
前提到達性の追加検査は別セッション。モデル driver の起動は別に60秒・16 MiBまで。
メモリ指定は Z3 が対象で、MoonBit プロセス全体の RSS 上限ではない。

```sh
moonx veri.mbtx check temporal/driver --module examples \
  --config '{"allow_drop":false}' --safety safe --bound 32 --timeout-ms 60000
moonx veri.mbtx check temporal/driver --module examples \
  --config '{"allow_drop":false}' --safety safe --complete
```

`--complete` は完全な有限モデルを全検査し、Z3 は使わない。
安全性・到達性・デッドロックは BFS、応答性は強連結成分を使って検査する。
部分探索は拒否する。公平性の指定は応答性の全検査で使用できる。
反例がなければ `safe-for-complete-model` または `unreachable-in-complete-model`。
`bound` フィールドは、証明書があればその遷移数、なければ検査した状態の最大最短深さを示す。
スイートでは `complete: true` と
その結果名を使い、`bound` とソルバー用 `limits` は省略する。
これは宣言された有限モデルの全検査であり、無限状態の実装の定理や `moon prove` の証明ではない。
JavaScript の互換検査器は、小さいモデル用の既存上限を保持する。

```sh
moonx veri.mbtx check temporal/driver --module examples \
  --config '{"allow_drop":false}' --response pending done --complete --fair --require-trigger
moonx veri.mbtx check temporal/driver --module examples \
  --config '{"allow_drop":true}' --response pending done --complete --fair --save dropped.json
moonx veri.mbtx explain dropped.json
```

応答性 `G(pending => F done)` の違反は、到達可能な要求から `done` を通らずに進み、
公平性を満たす循環を繰り返せる場合に見つかる。複数の単純な循環をつないだ反例も扱う。
弱公平性は既存の再生器と同じで、循環上にそのイベントが無効または状態を変えない地点があるか、
循環内でそのイベントによる状態変更が起きることを要求する。
無限実行が対象で、遷移のない停止状態に自己ループを追加しない。停止はデッドロック検査で確認する。
生成した lasso は遷移表と実際の driver の両方で再生する。最短性は保証せず、
証明書の構築が100万遷移を超える場合はエラーにする。

## 実装との操作列の差分テスト

`testing/state_machine` は次の2つを分けて定義する。

- `Model[M, Command, Output, View]`: `initial`、`step`、`observe`。独立した参照モデル。
- `System[S, Command, Output, View]`: `create`、`step`、`observe`、`close`。実際のライブラリ。

`step` は次の状態と操作の出力を返す。モデルだけは `None` により前提を満たさない操作を表す。
`replay(model, system, commands)` は初期状態と各操作後の出力・観測状態を比較し、
`Matched` / `Mismatch` / `InvalidCommand` と最初の不一致位置を返す。
`check` は core QuickCheck による生成・seed・標準の操作列と値の shrinking を提供する。
無効な操作列は生成・縮小の両方で除外し、毎回新しい実装を作成して終了時に close する。
予期した失敗は `Output` の `Result` などで表現し、予期しない例外は検査を失敗させる。
観測値は後の更新で変わらないスナップショットを返すこと。

`testing/state_machine/async` は async の create/step/observe/close を受け付ける。
`replay`、core の生成器・shrinker を使う `find_failure` / `shrink_failure` を提供し、
試行ごとのタイムアウトと cleanup を持つ。操作を1つずつ await するため、スケジューラを
制御したい場合は、イベントと adapter にその操作を明示する。任意の async 実装との対応を
形式的に証明するものではない。同期版は全4バックエンド、非同期版は Wasm / native。

実際の [Queue の比較と縮小](../testing/state_machine/replay_test.mbt)、
[非同期の再生と縮小](../testing/state_machine/async/replay_test.mbt)を参照。
`just test-model-check` がこれらを含む全検査を実行する。
