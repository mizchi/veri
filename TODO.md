# 追加基盤の実装状況

以下の4領域は API・論理モデル・利用例・テストを追加済み。証明と実行時の差分検査の
境界は各項目に記載する。独自公理や `proof_axiomatized` で未対応部分を仮定しない。

## 2. 整数の安全な演算・型変換

- [x] `Int` / `Int64` の `checked_add`、`checked_sub`、`checked_mul`。
- [x] `Int`・`UInt`・`Int64`・`UInt64` の全12方向の値保存変換。
  失敗しうる9方向は `checked_* -> Option`、無条件の拡幅3方向は標準型の値を直接返す。
- [x] 表現可能な場合だけ成功し、数学的整数値を保存する契約・仕様。
  演算本体と変換の `can_*` 判定は両整数モデルで証明。変換結果の仕様は
  `converted_*` で定義し、ネイティブキャスト本体との一致は BigInt で差分検査する。
- [x] 境界値と独立した BigInt モデルによる QuickCheck・標準 tuple / integer shrinking。

実装: `runtime/int32`、`runtime/int64`、`runtime/conversion`。
参照: [Why3 mach.int](https://why3.org/stdlib/mach.int.html)

## 3. バイト列・整数のエンコード

- [x] `bitvector` に `Bv8` / `Bv16` と4幅間の全12方向の符号なし変換。
- [x] Byte / UInt16 / UInt / UInt64 の LE / BE codec と BytesView の読み取り。
  `*_to_le_bytes` / `*_to_be_bytes`、値だけの `read_*`、次の位置も返す `decode_*`。
- [x] `decode(encode(x)) == x`、各バイトの範囲、消費バイト数のモデル上の証明。
  `read_end` は実行時の読み取り境界・消費長を証明。`byte_model` は Byte → Bv8 の
  値保存を証明。ネイティブ codec 本体・UInt16 の値対応は差分検査。
- [x] 切れた入力・境界値・ビューの開始位置を含む QuickCheck・Bytes / tuple shrinking。

実装: `bitvector`、`encoding`、`encoding/bitvector`、`runtime/bytes`。
参照: [Why3 bv](https://why3.org/stdlib/bv.html)

## 4. 代数法則と map / fold

- [x] 結合則・単位元・可換則を、供給された純粋な演算に対する条件として定義。
- [x] 条件を満たす演算について、分割集計・左右の fold・可換演算の順序交換を証明。
- [x] map の恒等則・合成則の帰納的証明、整数和の利用例、法則テスト。
- [x] 任意の演算が法則を満たすという仮定を導入しない。減算の結合則は負例で拒否。

実装: `algebra`。`runtime/list` は core と同じ `fold(init~, f)` / `raise?` と
`from_iter` を提供し、core との比較・callback の例外伝播・順序・長いリストを
含む実行時テストを持つ。論理モデルは純粋な演算が対象であり、
実行時 callback の副作用や関数本体との完全な対応は証明していない。
参照: [Why3 algebra](https://why3.org/stdlib/algebra.html)

## 5. グラフ・到達可能性

- [x] 経路・到達可能性・経路の連結と分解・重みの論理モデル。
- [x] 既存 queue / pqueue を使う探索と、fset の閉じた訪問集合の証明例。
- [x] BFS と非負重み Dijkstra。距離ラベルから最短辺数・最短重みを導く証明と、
  結果の経路・到達集合・距離を独立して検査する `check_bfs` / `check_dijkstra`。
- [x] Floyd–Warshall による全点対の比較、グラフ・操作列の shrinking。
  意図的に誤った「最短辺数＝最短重み」は重み0の1辺へ縮小する。

実装: `graph`、`runtime/graph`、`runtime/graph/checker`。BFS / Dijkstra の結果検査器は、
実際の内部配列に対する全体の健全性を両整数モデルで証明。可変状態を使う探索本体、
CSR 構築と `path_to` の配列変換は差分テストで検査する。
自己辺・多重辺・ゼロ重み閉路・非連結・不正入力・Int 距離のオーバーフローを含む。
構築は `new(vertex_count~)` / `from_array(edges, vertex_count~)` / `from_iter`、
走査は `iter` / `to_array`、構築・探索の失敗は `raise GraphError` に統一。
参照: [Why3 graph](https://why3.org/stdlib/graph.html)

## 利用例と検証

`examples/toolkit` に安全な確保サイズ、BE ヘッダ読み取り、符号変換、集計、経路探索、
有限集合の契約を合成する例を置いた。
`just prove`、`just prove-foundations-machine`、`just prove-machine`、
`just negative`、`just test-backends`、`just test-release`、`just package-check` で検証する。

## 次の証明段階

- ネイティブ整数変換・UInt16・codec の実行時の値保存を直接証明する。
  現行コンパイラの unsupported primitive operator / type を
  `just conversion-capabilities` で再現する。対応が追加されたら生成された意味を確認する。
- 純粋な callback と実行時 map/fold、可変状態を使う探索、CSR 構築・`path_to`・
  トポロジー返却配列・ArrayView 補助APIの変換を証明する。
  最短経路とトポロジーの検査器全体の健全性は証明済み。

## 追加の実用 API（実装済み）

- [x] `runtime/map` / `runtime/set`: core 型の再公開、任意順・重複拒否の内容検査。
  論理的な更新・削除・frame・要素数の法則を `fmap` / `fset` に追加。
  core 本体との対応は、衝突キーを含む shrinking 付き操作列テスト。
- [x] `runtime/search`: Int の lower/upper bound と整列判定の実装を両整数モデルで証明。
  core ソートの結果検査（昇順・重複数の保存）は差分テスト。
- [x] トポロジカルソートと単純閉路を FixedArray の証明書で返却。
  検査器本体から並べ替え・全辺の向き・非循環性、単純閉路・実在する閉路を両整数モデルで証明。
  `check_topology` で両判定を検査。DFS 本体は全到達性モデルで差分テスト。
- [x] Union-Find: サイズによる併合・経路圧縮、代表元・成分数・サイズ・コピー。
  論理モデルは2成分だけの併合・同値関係を証明。親配列の実装は操作列で差分テスト。
- [x] 不変の BytesView カーソルとパーサの zip/map/and_then/or_else。
  長さ付き入力、失敗時の位置保存、消費長、切れた入力を shrinking 付きで検査。
  読取境界の実装・消費長の合成則は証明済み。
- [x] graph 検査器の距離不等式を `runtime/graph/checker.relaxation` に分離し、
  実装を両整数モデルで証明。`just graph-capabilities` に現行呼出し制約の再現例を追加。
- [ ] core Map/Set と論理モデルを直接接続した実装証明。
- [ ] Union-Find の親配列・経路圧縮、DFS・パーサ合成の実装本体の証明。
- [x] `check_bfs` / `check_dijkstra` が受理した結果の最短性・正確な到達性・親チェーンを、
  検査器本体から両整数モデルで証明。距離 getter と利用側の `shortest_at` 契約まで接続。
  任意の生配列に対して前提なしで検査し、実際の辺配列の全有限経路が対象となる。
- [x] `runtime/graph/topology` に順序・閉路検査器全体の実装証明を分離。
  公開 Graph API と利用側の非循環/循環の契約まで接続し、O(V+E) を維持。
  任意の証明書とビューのオフセットを1,000件、2万頂点の鎖・閉路も検査。
- [ ] CSR 構築、`path_to`・トポロジー返却配列・ArrayView 補助APIの変換の実装証明。

`just verify-extensions` で追加 API をまとめて検証する。

## 時相論理・状態遷移

- [x] `just temporal`: Z3 による固定ジョブモデルの安全性の帰納的検査と、
  活性・弱公平性の bounded lasso 検査。到達する正例、壊した遷移、要求消失の反例を含む。
  有限状態の全探索と比較し、SAT の実行列を独立に再生する。
- [x] `checks/temporal/Job.tla` を Apalache で実行・照合する。
  `just apalache` で Nix による版固定の導入、Job 4件＋TaskGroup 11件の Z3 との照合、
  ITF の反例を MoonBit へ戻して再生する。深さ8の有限モデルが対象。
- [x] 固定ジョブモデルと MoonBit の `step(state, action)` を接続。
  private な `#proof_pure` と公開契約を使い、両整数モデルで有限実行列の安全性・
  enabled・状態符号化を証明。実際の遷移表から Z3 の制約を生成し、反例を MoonBit で再生。
  全探索との照合、1,000件の shrinking 付き QuickCheck、不正証明書も検査。
- [x] 汎用の型付き状態遷移モデル、入力・操作列の shrinking、実装との操作列の差分テスト。
  列挙済み有限モデルの Apalache との往復も実装済み・テスト対象。
- [ ] 任意のプログラムとの対応、JSON 入出力・SMT/TLA+ 生成・ループ評価の実装証明。
- [ ] 汎用モデルの帰納的証明と時相式の拡張。bounded safety / reachability / response / deadlock と
  有限モデルの全検査は実装済み。Bounded / Proved / Unknown を混同しない。
- [x] TaskGroup の子2個＋本体の有限モデル。no_wait・allow_failure・キャンセル・
  即時終了・終了待ち・グループ defer を扱う。共用遷移の証明、全16設定の照合、
  shrinking 付き QuickCheck、Z3 の弱公平性と故障モデルの反例、実 async の履歴検査。
  `just verify-task-group`。実ランタイムとの対応はテスト済み・未証明。
- [ ] TaskGroup の任意個数・入れ子・spawn_loop・終了処理中の追加キャンセル・
  非同期 cleanup の詳細。ソルバの任意のスケジュールを実 async で再生する制御器と
  実装/モデルの対応証明。チャネル・タイマー・実時間の意味論。
- [x] `model_check`: client / driver を汎用化。Job・TaskGroup・lease-clock を
  version 1 の export / replay 形式へ統一し、状態と JSON snapshot、設定と性質を分離。
  反例・公平性の評価、SMT 生成、Z3 との通信を MoonBit で実装。
  `moonx veri.mbtx` と公開用 `cmd/model-check`、日英のモデル追加手順を用意。
  JavaScript の既存ツールは互換 API・独立した照合先として維持。
- [x] `examples/lease_clock`: Quint の脆弱モデルと修正候補を MoonBit に移植。
  深さ上限付きの共用探索器、範囲を超えた検査の拒否、Z3/Apalache との照合、
  MoonBit 再生、独立実装・shrinking 付き QuickCheck。修正した有限モデルの470状態を全探索。
  `just verify-lease-clock` / `just apalache-lease-clock`。celld の実装には接続しない。

## 実用ワークフロー

- [x] 期待結果付きの CI スイート、全ケースの結果集約、不一致・unknown・実行エラーの非ゼロ終了。
- [x] 設定・モデル・反例の保存、イベント名とフィールド差分の説明、モデル同一性を検査した再生。
  共通の入力縮小器は複雑度の減少・失敗の保存・試行上限を要求する。
- [x] 名前付き Spec から Client・遷移表・述語表を生成。3モデルを移行し、閉包と部分探索を区別。
- [x] 正常終了を除くデッドロックと、応答性の前提到達性の追加検査。
- [x] 衝突を Eq で解決する状態ハッシュ、状態数・遷移セル数・Z3 時間/メモリ/入出力の予算、
  深さ16の制限の緩和、1セッションでの増分 SMT、完全な有限モデルの安全性・到達性・デッドロック全検査。
- [x] 独立モデルと実装の操作列の差分テスト。同期・async の再生、fresh state と cleanup、
  core QuickCheck による生成・操作列と値の shrinking。スケジューラ操作は adapter で明示する。
- [x] 有限モデルの応答性・弱公平性の全検査。強連結成分から公平な lasso を構築して再生。
  `--complete --save`、全域での前提到達性、CI スイートに接続。
  独立した積状態の検査器との3,000件の QuickCheck・shrinking、2万状態の鎖で検査。

使い方は [実用ワークフロー](docs/model-workflows.ja.md)。これらの汎用検査器の実装証明や、
無限状態・任意の非同期スケジュールについての証明を追加したわけではない。
