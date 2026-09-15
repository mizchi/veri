# 検証手順と性質テスト

[English](verification.md) | [README](../README.ja.md)

## GitHub Actions

[CI](../.github/workflows/ci.yml) は `main` への push、pull request、手動実行で動く。
Ubuntu 24.04 上で以下を独立したジョブに分け、最後の `CI result` が全成功を要求する。

| 検査 | ローカルでも使えるコマンド |
| --- | --- |
| フォーマット・型・公開 API・参照値・コンパイラ対応範囲 | `just ci-check` |
| 本体と examples の debug / release、4バックエンド | `just ci-test js`（`wasm` / `wasm-gc` / `native` も実行） |
| ツールのテスト、SMT・時相モデル・期待結果付きスイート | `just ci-models` |
| 通常整数の証明 | `just ci-prove-mathematical` |
| 偽の命題を拒否する負例（CI は4分割） | `just negative` |
| 機械整数の証明 | `just ci-prove-machine` |
| 配布物を別プロジェクトから利用・証明 | `just package-check` |
| Nix の Apalache と Z3 の照合 | `just apalache apalache-lease-clock` |

MoonBit `0.10.12+1634b282e`、Z3 `4.16.0`、CVC5 `1.3.4` を固定し、
取得したアーカイブの SHA-256 を照合する。Node.js は `24.21.0`、just は `1.58.0`、
Apalache は `flake.lock` に基づく `0.62.2`。Actions もコミット SHA に固定し、
Dependabot で更新を提案する。ツールと依存のみをキャッシュし、検査は毎回実行する。
ログと生成した検証レポートは7日間の artifact として残す。
CI では `VERI_PROVER_JOBS=2` と `VERI_PROVER_FINAL_TIMEOUT=6` により、
Why3 の同時ソルバー数と最終段階の制限秒数を調整する。ローカルの既定値は16と2。
負例は `VERI_NEGATIVE_SHARD=0`〜`3`、`VERI_NEGATIVE_SHARDS=4` で68件を重複なく分配する。

MoonBit の固定値は [.github/toolchain.env](../.github/toolchain.env) で管理する。
上流の版別アーカイブは60日で削除されるため、この pin は2026年11月8日より前に更新する。
更新時はコンパイラと core を同じ版に揃え、SHA-256 と全ジョブの結果を確認する。

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

## QuickCheck による性質テスト

`bounds/` と `runtime/` の性質を `moonbitlang/core/quickcheck` で、
固定 seed `20260914`〜`20260927` により検査する。通常は1,000件、
グラフは小さい重み500個・境界重み500個・編集操作列200件について、全始点・終点を
Floyd–Warshall と比較する。生成サイズは最大64、コレクション操作列と赤黒木は最大128、
グラフは最大7頂点・生成する入力辺48本。頂点番号と辺順の変更を500件、
到達可能な辺を1本追加してから距離・到達性・親頂点を改ざんする検査を500件行う。
独立モデルは `Int64?` で到達不能と Int 上限を超える有限距離を区別し、返された経路も
実装の辺検索や証明書検査を使わず元の辺配列で確認する。
標準 tuple / array shrinking で元の入力を縮小してから再実行する。
追加 API は、Map / Set の衝突操作列、二分探索、Union-Find、トポロジカル順序、
パーサ合成2種類を各500件、距離不等式を1,000件検査する。
検査器の生配列への任意の距離・親の改ざんも1,000件検査し、各入力で正常な証明書の受理も確認する（seed `20260926`）。
トポロジーは任意の証明書と独立した参照実装を1,000件比較し、各入力で既知の DAG または
閉路の正常な証明書も確認する（seed `20260927`）。標準 tuple / array shrinker を使用する。
`just quickcheck js`（または `wasm`、
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
