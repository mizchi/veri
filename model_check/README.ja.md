# モデル共通の client / driver

[English](README.md)

Job・TaskGroup・lease-clock の export と反例再生を共通化する。
新しいモデルは、実行可能な状態・イベント・遷移・述語を `Client` に渡し、
モデル固有の設定を小さな driver で解釈する。
共通ライブラリは `mizchi/veri/model_check`、CLI は `mizchi/veri/cmd/model-check` に置く。
モデル固有のコードだけを `examples` に残す。これらの追加分はまだ公開していない。

## moonx で検査する

この checkout のルートで実行する。MoonBit と Z3 が必要で、CLI の実行に Node.js は使わない。

```sh
# 脆弱モデルの二重 writer を検出し、MoonBit の step で反例を自動再生する
moonx veri.mbtx check lease_clock/driver --module examples \
  --config '{"variant":0,"bound":8}' --safety single_writer --bound 8

# 完了アクションに弱公平性を課して応答性を検査する
moonx veri.mbtx check temporal/driver --module examples \
  --config '{"allow_drop":false}' --response pending done --fair --bound 8

moonx veri.mbtx --help
```

`veri.mbtx` は checkout 内の `cmd/model-check` を Wasm で起動するだけのランチャー。
モデルの起動、SMT の生成、Z3 との通信、結果の読み取り、反例再生は MoonBit で実装している。
外部プロセスには `moonbitlang/async/shell` を使い、引数をシェル文字列に連結しない。
通常の `moon run cmd/model-check --target wasm -- ...`、`just model-check ...` でも実行できる。

この変更を含む版を公開した後は、checkout なしで次の入口を使える。
モデルの `--module` は検査したいプロジェクトを指す。

```sh
moonx mizchi/veri/cmd/model-check check my_model/driver \
  --module ./my_project --config '{}' --safety safe --bound 8
```

`export` は遷移表を JSON で出力する。`replay` は `--witnesses FILE` から
`{states, actions, loop_start?}` の JSON 配列を読み、受理結果を返す。
`--config-file FILE` も使用できる。`--safety P`、`--reachable P`、`--response P Q` の
いずれか1個を指定する。`--fair` はモデルの `justice` を選び、`--justice '[1,2]'` は明示指定。
探索の深さはモデルの `--config` にある設定、SMT の検査深さは CLI の `--bound` と区別する。

結果は標準出力に JSON で返す。反例が見つかった場合も問い合わせの成功として終了コード0を返す。
入力不正、Z3 の `unknown`・タイムアウト・起動失敗、または自動再生の拒否は非ゼロ終了する。
汎用の返り値は上限付きの結果であり、この CLI 自体が無制限の証明を返すことはない。

MoonBit のコードから直接呼ぶ場合は [runner](runner/runner.mbt) を使う。

```moonbit
let driver : @runner.Driver = {
  driver_pkg: "lease_clock/driver", module_dir: "examples", target: "wasm",
}
let result = driver.check(
  { "variant": 0, "bound": 8 }, @model_check.Safety("single_writer"), bound=8,
)
```

これは `async fn` の中で使う。`Driver::load`・`Driver::replay` も提供する。
プロセスを使う `runner` と CLI は Wasm / native、純粋なモデル API・driver・SMT 生成は
js / wasm / wasm-gc / native に対応する。

## 既存の JavaScript ツールから検査する

リポジトリ直下の Node.js ES module から実行する例。

```js
import {createModelClient} from "./tools/model-client.mjs";

const client = createModelClient({
  driver: "lease_clock/driver",
  defaults: {variant: 0, bound: 8},
});
const property = {kind: "safety", predicate: "single_writer"};
const model = client.load();
const result = client.check(property, {bound: 8});
console.log(result.result); // counterexample
console.log(result.witness.actions.map(a => model.actions[a]));
console.log(client.replay([result.witness], {property})); // [true]
```

`check` は Z3 で探索し、得られた反例を MoonBit の実際の `step` で再生する。
再生に失敗した結果は返さず、例外にする。`replay` は独立した証明書の確認にも使える。
Apalache では同じ `load` の結果を `finiteTla` に渡し、`decodeFiniteTrace` で取り出した
実行列を同じ `replay` に渡す。既存の `just apalache` / `just apalache-lease-clock` がその例。

| 操作 | 意味 |
| --- | --- |
| `load(config = {})` | 設定からモデルを構築し、共通形式の遷移表を取得・検査 |
| `check(property, {config, bound, justice, onQuery})` | 上限付き Z3 検査と MoonBit 再生 |
| `replay(witnesses, {config, property, justice})` | 各証明書の受理結果を `Bool` の配列で返す |

`config` は `defaults` を浅く上書きする。`cwd`・`moduleDir`・`target` も指定できる。
デフォルトはこのリポジトリ・`examples`・`js`。
モデルを切り替える際は、証明書を生成したものと同じ設定を `replay` に渡す。

| 性質 | 指定 | 証明書の受理条件 |
| --- | --- | --- |
| 安全性 | `{kind: "safety", predicate: "safe"}` | 実行中に述語が偽になる |
| 到達可能性 | `{kind: "reachability", predicate: "done"}` | 最後の状態で述語が真になる |
| 応答性 | `{kind: "response", trigger: "pending", goal: "done"}` | `G(trigger => F goal)` を破る無限ループがある |

`justice` は弱公平性を課すアクションの ID 配列。デフォルトは `[]` で、
モデルが提示する `model.justice` は自動適用しない。
公平性が必要なら `check` と `replay` の両方に明示する。
実行しても状態が変わらないアクションは、公平性上は有効な進捗として扱わない。

## MoonBit モデルを接続する

[types.mbt](types.mbt) の `Client[State, Event, Snapshot]` が接続用の型。
`State` は `Eq`、`Snapshot` は driver から出力するため `ToJson` が必要。
状態は不変に扱い、`Eq` は状態全体を比較する。

| フィールド | モデルが渡すもの |
| --- | --- |
| `initial` / `states` | 実際の初期状態と、ID 順の実行可能な状態 |
| `events` | ID 順のイベント。引数があるイベントは選択肢を列挙 |
| `step` | 決定的な `(State, Event) -> State?`。ガードを満たさなければ `None` |
| `holds` | `(State, String) -> Bool?`。未知の述語名は `None` |
| `model` | JSON 出力用の `Model[Snapshot]`。上の状態・イベント・述語と一致させる |

`model` は `initial`、`actions`、`states`、`transitions`、`predicates`、`justice`、
`exploration` を持つ。無効な遷移の ID は `-1`。
反例再生は `Client` の実状態・`step`・`holds` から判定し、出力済みの辺や述語値を根拠にしない。
スナップショットから実状態への逆変換も不要。

[Job の adapter](../examples/temporal/explorer/explorer.mbt) は有限な型の全領域を列挙する例、
[lease-clock の adapter](../examples/lease_clock/explorer/explorer.mbt) は `explore` による深さ付き BFS の例。
[TaskGroup の adapter](../examples/task_group/explorer/explorer.mbt) は到達状態の閉包を列挙する例。
既存の `Graph::client` は設定を `step` のクロージャに閉じ込めている。

モデルの driver は設定型と `serve` の呼び出しだけでよい。
[Job の driver](../examples/temporal/driver/main.mbt) は次の形になる。

```moonbit
struct Config {
  allow_drop : Bool
} derive(@json.FromJson)

fn main {
  @model_driver.serve((config : Config) => @explorer.client(config.allow_drop))
}
```

`moon.pkg` ではモデルの explorer と、
`"mizchi/veri/model_check/driver" @model_driver`、`"moonbitlang/core/json"` を import する。
`serve` は純粋な client 構築関数も、探索エラーを送出する関数も受け取れる。
I/O を使わず検査する場合は `Client::accepts(Property, Witness, justice=...)`、
JSON の接続部分だけを試す場合は `dispatch(argument, make_client)` を使う。

## 通信形式と検査の範囲

driver は1個の JSON 引数を読み、`{version: 1, result: ...}` を出力する。
リクエスト例は次のとおり。

```json
{
  "version": 1,
  "mode": "replay",
  "config": {"allow_drop": false},
  "property": {"kind": "response", "trigger": "pending", "goal": "done"},
  "justice": [],
  "witnesses": [{"states": [0, 1, 1], "actions": [0, 2], "loop_start": 1}]
}
```

`export` の場合は `property` を省略できる。`justice` と `witnesses` は空配列を渡す。
JavaScript の証明書は `{states, actions, loop}`。
有限実行の `loop: null` は MoonBit の optional field に合わせて `loop_start` の省略へ変換する。
ループの場合は最後の状態が `states[loop]` と一致する必要がある。
バージョン不一致・設定の型違い・探索の資源上限などは非ゼロ終了し、成功として扱わない。

`exploration: Some(scope)` の `complete` が偽なら、探索深さを超える再生と応答性検査を拒否する。
`None` は adapter が状態領域の全体または到達状態の閉包を列挙したという宣言であり、
打ち切りを隠すためには使わない。`explore` の状態数上限超過は例外になる。

これらは実行可能な検査で、汎用の帰納証明ではない。
`temporal/client`・`task_group/client` にある `moon prove` 用の契約はモデル固有のまま維持する。
JSON 変換や共通の反例評価器を、その証明の対象に含めたとは主張しない。

```sh
just test-model-check   # 共通評価器・プロトコル・4バックエンドの debug/release
just verify-model-check # 上記 + 3モデルの Z3 検査と反例再生
```
