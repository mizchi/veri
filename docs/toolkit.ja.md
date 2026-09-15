# 実行時 API とグラフ検査

[English](toolkit.md) | [README](../README.ja.md)

## Map / Set・探索・依存関係・パーサ

`runtime/map.Map` と `runtime/set.Set` は **core の型そのものを再公開**する。
標準の `Map` / `Set` と相互に渡せ、挿入・削除・走査は同じ実装を使う。
`matches_entries` / `matches_elements` は必要時だけ呼ぶ内容検査で、入力順を問わず、
重複キー・重複要素を拒否する。通常の操作に検査コストやモデルのコピーは加わらない。
`fmap.updated` / `removed` と `fset.added` / `removed` は対応する論理的な遷移を定義し、
参照・所属・他の要素の保存・要素数の法則を証明する。core 本体との対応は、
ハッシュがすべて衝突するキーを使う操作列と独立した配列モデルで差分検査する。
論理的な等値と対応させるキーは、`Eq` が同値関係を満たし、等しいキーのハッシュが一致する必要がある。

`runtime/search` は `FixedArray[Int]` 上の `lower_bound`（最初の `>=`）と
`upper_bound`（最初の `>`）を提供する。整列済みという事前条件の下で、実装本体の
境界条件を通常・機械整数モデルの両方で証明する。O(log n)、配列コピーなし。
`is_sorted` は事前条件と一致する O(n) の検査で、こちらも実装を証明する。
入力の整列は呼び出し側が保証するか、先に `is_sorted` で調べる。
`check_sort(before, after)` は昇順と重複数の保存を実行時に検査する。
core のインプレースソートを検査するときは、ソート前のコピーを `before` に渡す。
この Map ベースの結果検査器は差分テストが保証の境界である。

`Graph::topological_sort()` は `Ordered(order)` または `Cyclic(cycle)` を返す。
両方の証明書は `FixedArray[Int]` で、順序は全頂点の並べ替え、閉路は先頭頂点を末尾に
繰り返した単純閉路（自己辺なら `[v, v]`）。`graph.check_topology(witness)` で判定ごと検査できる。
`check_topological_order(order)` / `check_cycle(cycle)` は各配列を直接受け取る。
**検査器全体の実装と健全性を、通常・機械整数の両モデルで証明している。**
順序の受理は全頂点の一意な出現・全辺の向き・非循環性を、閉路の受理は単純性・実在する
連続辺・非空の閉路の存在を保証する。`topological_order` / `simple_cycle` / `acyclic` /
`cyclic` / `valid_topology` を利用側の契約で使える。

実装は `runtime/graph/topology` に分離し、実際の辺配列と証明書を検査する。
順序は新しい順位表、閉路は新しい訪問表と CSR の隣接範囲を使い、どちらも O(V+E) 時間・
O(V) 空間。閉路の検査は範囲と辺の両端を再確認するため、不正な CSR オフセットから
架空の辺を受理したり範囲外アクセスしたりしない。重みは使わない。
DFS 本体・返却配列の構築は差分テストの対象で、検査器の証明はその正しさを前提にしない。
全到達性モデル、任意の証明書、2万頂点の鎖・閉路、shrinking 付き QuickCheck でも確認する。

未公開の旧 API からは `check_topological_order(order[:])` を `check_topological_order(order)` に
変更する。`ArrayView[Int]` 用には `check_topological_order_view` / `check_cycle_view` もあり、
ビューをコピーして検査する。このコピーはオフセット付きビューの差分テストで確認する。
現行の証明器では ArrayView の読み取りに未対応のため、証明コードでは FixedArray の API を使う。

`runtime/union_find.UnionFind::new(n)` は `0..<n` の要素を管理する。
`find` / `same` / `union` / `component_size` / `component_count` / `copy` / `to_array`
を提供し、不正なサイズ・要素は `raise UnionFindError`。
`union` は併合できた場合だけ `true` を返す。代表元の番号は仕様に含めない。
サイズによる併合と経路圧縮を使い、平坦な成分ラベルとの操作列テストで検査する。
`union_find` の論理モデルでは「指定した2成分だけを併合する」性質と同値関係の法則を証明する。
可変な親配列・経路圧縮の実装本体は未証明。


`examples/toolkit/kruskal.mbt` に、core のソートと Union-Find を組み合わせて
無向グラフの最小全域森を求める実行例も置く。この例の最適性は形式証明していない。

`runtime/bytes/cursor` は不変の `Cursor` と `Parser[T]` を提供する。
`Cursor::read(parser)` は `Some((value, next_cursor))` または `None`。
`byte`・各幅の LE/BE 読取・`take` を `zip` / `map` / `and_then` / `or_else` で合成できる。
`length_prefixed_uint_be()` は32 bit BE の長さと後続の `BytesView` を読み、
切れた入力・Int に収まらない長さを拒否する。読み取りでバイト列はコピーしない。
元カーソルは成功・失敗のどちらでも変わらず、fallback は元の位置から試す。
callback 自身の副作用は巻き戻さない。`read_end` の実装と `encoding.read_composition` の
消費長の法則は証明済みで、native codec・パーサ合成は shrinking 付きの差分テストで検査する。

```sh
just verify-extensions # 上記の証明・負例・4バックエンドの debug/release テスト
just graph-capabilities # 最短性・トポロジーの公開契約と、ArrayView 補助APIの変換制約を確認
```

BFS/Dijkstra の **検査器全体の健全性**を、通常・機械整数の両モデルで証明する。
`runtime/graph/checker.check_certificate` は任意の入力を検査し、受理した距離が実在する経路で
達成され、すべての経路の費用以下であり、`None` の頂点には到達できないことを保証する。
親チェーンの始点への到達、全辺の距離不等式、配列長・添字・非負重みも検査する。
`relaxation` は和を作らず `next <= cost + weight` を判定し、オーバーフローする迂回路も扱う。
公開 `Graph::check_bfs` / `check_dijkstra` は実際の内部配列を直接渡し、同じ証明を利用する。
`certified` / `shortest_at` と契約付きの `SearchResult::distance` を利用側の証明で使える。
現行 core Map / Set と `ArrayView` 補助APIのコピー処理は、この実装証明の対象外である。
証明対象は受理した結果の健全性で、すべての妥当な証明書を受理する完全性は未証明。

## 安全な整数演算・codec・代数法則・グラフ

`runtime/int32` / `runtime/int64` は `checked_add`・`checked_sub`・`checked_mul`
を提供する。`Some(value)` は正確な数学的結果、`None` は結果が型の範囲外であることを
表す。両整数モデルで契約を証明し、機械整数モデルでは中間演算の安全性も検査する。
`runtime/conversion` は `Int`・`UInt`・`Int64`・`UInt64` の全12方向を
提供する。失敗しうる9方向は `checked_int_to_uint`・`checked_int64_to_int` のように
`checked_` を付け、`Option` を返す。必ず成功する3方向の拡幅
（`int_to_int64`・`uint_to_int64`・`uint_to_uint64`）は core のキャストで値を直接返す。
`can_*` で正確な範囲判定を証明し、`converted_*` で値保存の仕様を定義する
（拡幅の結果をこの仕様に渡すときは `Some` で包む）。
組み込み数値型には外部パッケージから直接公開メソッドを追加できないため、
標準型を直接受け取る関数として提供する。
現行の証明フロントエンドはネイティブ変換を扱えないため、その対応は仮定せず
独立した `BigInt` 演算で差分検査する。`just conversion-capabilities` で
UInt16 の変換を含む対応状況を記録する。

`runtime/bytes` は MoonBit の型名に合わせ、`byte_to_bytes` と
`{uint16,uint,uint64}_to_{le,be}_bytes` を提供する。core の `to_le_bytes` /
`to_be_bytes` と同じ命名で、32 bit 整数は実行時の `UInt` に合わせて `uint` とする。
`read_byte`・`read_{uint16,uint,uint64}_{le,be}` は
`(data : BytesView, offset : Int)` を受け取り、標準型の値を `T?` で返す。
逐次解析用の `decode_byte`・`decode_{uint16,uint,uint64}_{le,be}` は
`Decoded[T]?` を返し、`value` とビュー先頭からの `next_offset` を持つ。
負数・オーバーフロー・切れた入力は `None`、読み取り後の余剰バイトは許容する。
`read_end` は範囲判定と消費長を証明する。`encoding` は LE/BE の往復、バイトの範囲、
長さを証明し、`encoding/bitvector` で Bv8/Bv16/Bv32/Bv64 と接続する。
`runtime/bytes.byte_model` は Byte と Bv8 の値保存を証明する。
ネイティブ codec の値、UInt16 のキャスト、ビュー内オフセットは差分検査の対象で、
codec 本体の全入力の値保存は未証明。16 bit は MoonBit の `UInt16` を使い、
エンコード結果は新しい不変の `Bytes` を返す。

`algebra` は供給された純粋な演算に対する `associative`・`identity`・`commutative`・
`monoid` と、`runtime/list.List` 上の構造的モデルを定義する。`fold_split` は法則を
仮定せず、`fold_partitions` / `fold_directions` は monoid、`reorder_partitions` は
さらに可換則を要求する。`map_identity` / `map_composition` は構造帰納法で証明する。
実行時の `List::map(f)` / `List::fold(init=initial, f)` は core/list と同じ
`raise?` の callback を左から順に呼び、例外をその場で伝播する。
`List::from_iter` は標準 `Iter` を順に消費する。core との QuickCheck 比較と shrinking、
法則・例外時の呼び出し順・長いリストをテストする。callback の副作用は純粋なモデルの対象外。
任意の演算が法則を満たすという仮定は追加しない。

`runtime/graph.Graph::from_array(edges, vertex_count=n)` は頂点 `0..<n`、非負の
Int 重みを持つ有向グラフを検査し、入力辺をコピーする。自己辺と多重辺を許容する。
`Graph::new(vertex_count=n)` は辺のないグラフ、`from_iter(edges, vertex_count=n)` は
標準 `Iter` から構築する。`iter()` / `to_array()` は始点の頂点番号順、同じ始点の辺は
入力順で走査する。構築と探索は値を直接返し、`raise GraphError` により
MoonBit の `try ... catch` でエラーを扱える。
`bfs(source)` は最小辺数、`dijkstra(source)` は最小重みを求め、既存の FIFO queue と
最小 priority queue を使う。結果の `distance(vertex)` と `path_to(vertex)` は、
無効・到達不能な頂点で `None` を返す。経路は始点と終点を含む新しい配列。
無効な始点はエラーになり、到達可能な頂点の最小距離が Int を超える場合もエラーにする。
オーバーフローする迂回路があっても、表現可能な最短経路は拒否しない。
`check_bfs` / `check_dijkstra` は経路・辺の不等式・到達集合の閉包を独立して検査する。
この診断用検査は親チェーンと辺の走査により最悪 O(V(V+E)) 時間で、探索時には自動実行しない。
グラフは不変の CSR 配列を保持する。検査器は辺・距離・親の `FixedArray` を読み取るだけで、
証明のない配列変換を挟まない。探索処理から与えられた証明書の正しさを前提にしない。

`graph` は経路の連結・分解、重みの加法性、`fset` 内の閉包、距離ラベルからの
最短性の証明書を用意する。論理経路は後続頂点列（始点を省き、終点を含む）で、
実行時の `path_to` は始点も含む。検査器の `path` は多重辺を区別するため、実際に保存された
辺の番号を終点側から並べた `List[Int]` を使う。`path_cost` は数学的整数の和で、
BFS では辺数、Dijkstra では重みの合計になる。親チェーンの帰納法で距離を達成する経路を、
経路の帰納法で全経路に対する下界と到達集合の閉包を証明する。
探索と検査器は独立した Floyd–Warshall モデルとも比較し、ゼロ重み閉路・非連結・
オーバーフロー・改ざんされた証明書をテストする。BFS / Dijkstra の探索本体、CSR の構築、
`path_to` の可変配列への変換は差分テストの対象で、形式証明はしていない。
`examples/toolkit/checked_graph.mbt` では公開検査 API の呼び出しから任意頂点の最短性を導く。

`just quickcheck-graph js`（または `wasm`・`wasm-gc`・`native`）で graph の性質テストを実行する。
`just verify-graph` は4バックエンドの debug/release テスト、通常・機械整数モデルでの
検査器本体・論理法則・利用側契約の証明、偽の主張を拒否する負例検査をまとめて実行する。
三角形の例では、BFS は1辺の直行経路を、最小重みは重み3の直行経路より軽い
重み2の2辺経路を証明する。経路が存在するだけでは最短性を示せず、負例では
重み3の経路を最短とする主張が証明されないことを確認する。
