# コレクションと配列の更新

[English](collections.md) | [README](../README.ja.md)

## 実行時コレクションの API

独自型には `List::new()`・`Stack::new()`・`Queue::new()`・`IntMinQueue::new()`・
`IntSet::new()`・`Tree::new()` とメソッドを用意する。更新は新しい値を返し、
元の値も引き続き使える。`IntMinQueue` は重複を保持する Int 専用の最小優先キュー、
`IntSet` は重複のない Int の集合。既存の自由関数は同じ契約付き実装へのエイリアスとして残す。

```moonbit
// "mizchi/veri/runtime/queue" を import。
test "persistent queue and Iter" {
  let original : @queue.Queue[Int] = @queue.Queue::new()
  let queue = original.push(1).push(2)
  assert_true(original.is_empty())
  assert_eq(queue.iter().map(x => x * 2).to_array(), [2, 4])
}
```

`iter()` は中間の配列を作らず、独立した走査状態を返す。順序はリスト順、スタックの
先頭順、キューの FIFO 順、最小優先キュー・集合の昇順、木の中間順。
イテレーターと配列変換の対応は実行時テストで検査し、証明契約は付けていない。
List のメソッド名は core に合わせて `prepend`・`concat`・`rev` とし、自由関数の
`cons(value, list)`・`append(left, right)`・`reverse(list)` も使える。

## FixedArray の更新と範囲操作

`runtime/array` は組み込みの `FixedArray[T]` を直接更新する。範囲は
`Range { start, count }` で指定し、`[start, start + count)` を意味する。
更新操作は成功時に `true`、不正な添字・範囲では変更せず `false` を返す。
配列末尾の空範囲も有効。
`Range` は `#valtype` の小さなレコード。フィールド名で開始位置と個数を区別し、
証明対象でも呼べる位置引数の API にしている。現行の証明変換は契約付き本体での
名前付き引数の呼び出しに未対応。`Range` の構築自体は境界検査を行わず、
不正な値は各操作が検査する。

| API | 動作 |
| --- | --- |
| `valid_range(length, range)` | 極端な不正入力でも加減算をオーバーフローさせず範囲を検査 |
| `set(array, index, value)` | 単一要素の書き込み |
| `swap(array, left, right)` | 2要素の交換。同じ添字も有効 |
| `fill(array, value, range)` | 指定範囲を同じ値で埋める |
| `blit(source, target, source_range, target_start)` | 同一配列の重複範囲を含むコピー |
| `blit_disjoint(source, target, source_range, target_start)` | **異なる配列間**の契約付きコピー |
| `copy_within(array, source_range, target_start)` | 同一配列内のコピー。重複範囲でも更新前のコピー元の値を使う |

`set`・`swap` は定数時間、範囲更新は O(count) 時間・定数の補助領域で動作する。
`copy_within` は大きい添字へ移動するときに後ろから書き込み、一時配列を作らない。
これは計算量の説明であり、core との実測性能の同等性を保証するものではない。
`blit` は参照の同一性を調べ、同一配列には `copy_within`、別配列には
`blit_disjoint` を使う。この振り分けは実行時テストで検査し、証明契約は持たない。
証明対象のコードでは `copy_within` または `blit_disjoint` を選ぶ。
後者に同じ配列を渡す呼び出しは Why3 が共有参照として拒否する。
`range_in_bounds(length, start, count)` は数学的な端点を扱う **証明専用** の述語。
実行時の範囲検査には `valid_range(length, range)` を使う。

```moonbit
// "mizchi/veri/runtime/array" を import。
test "range updates" {
  let xs : FixedArray[Int] = [0, 1, 2, 3]
  assert_true(@array.fill(xs, 9, { start: 1, count: 2 }))
  assert_true(@array.copy_within(xs, { start: 0, count: 3 }, 1))
  assert_eq(xs, [0, 0, 9, 9])
}
```

通常・機械整数の両モデルで、範囲検査、安全な添字アクセス、整数演算の範囲、
ループの停止性を証明する。加えて、`set` が書く値、`swap` の交換する値
（関数内の assertion）、`fill` の全対象要素、`blit_disjoint` の対象要素と異なるコピー元の
一致を証明する。公開される `swap`・`copy_within` の契約は成功条件・範囲まで。
`examples/bridges.fill_and_read` では別モジュールから `fill` と `get` を合成する。

`arrays/range` は更新前後の完全な仕様として `unchanged_outside`・`filled`・
`copied`・`exchange` を定義する。7個の補題は単一書き込み、swap とその取り消し、
空操作、fill・コピーを1要素延ばすときの性質を証明する。添字は数学的整数で、
[Why3 map](https://why3.org/stdlib/map.html) の範囲等価・交換を利用する。
`copied` は重複範囲でも必ず**更新前**のコピー元を参照する。
このモデルの証明だけで実行時実装との完全な対応が証明されるわけではない。

現行コンパイラでは契約内の `old(...)` が使えず、`proof_let` による snapshot は
内部の assertion failure になる。そのため、更新前後の完全な対応、更新範囲外の保存、
失敗時に変更しないこと、重複コピーの内容は、snapshot を使う独立した参照実装と
QuickCheck で比較する。**実行時関数についての全入力の形式証明には未対応**。
配列更新の8個の性質は各1,000件で、操作列、全幅の整数、有効範囲付近の入力を検査し、
core のタプル・配列 shrinker を使う。誤った前向きコピーが3要素の重複ケースまで
縮小される回帰テストもある。負例の証明検査では、誤った fill の値、範囲の桁あふれ、
モデルでの範囲外書き込み、変更済みコピー元の参照を拒否する。

`just array-capabilities` はコンパイラの制約と共有参照の拒否を検査し、
`_build/array-capabilities.json` に記録する。`just verify` にも含む。
ローカルの証明注釈では配列参照を predicate にまとめ、コンパイラが更新関数を
Why3 の ghost コードとして扱う問題も回避している。新たな仮定付き契約や独自公理は
追加していない。実装状況と証明範囲はリポジトリの [TODO.md](../TODO.md) を参照。

## コレクションのモデルと実装

| 論理パッケージ | 同梱 Why3 の理論 | 意味 |
| --- | --- | --- |
| `seq` | `seq.Seq`・`Reverse`・`Mem`・`Occ`・`Permut` | 数学的な長さと添字を持つ有限列 |
| `list` / `list/indexed` | `list.List`・`Length`・`Append`・`Reverse`・`NthNoOpt`・`NumOcc` | 帰納的リスト。添字と出現数は必要に応じて追加 import |
| `list/conversions` | `seq.OfList`・`seq.ToList` | 論理リストと有限列の変換 |
| `bag` | `bag.Bag` | 多重集合。和は出現回数を加算し、差は0で切り詰める |
| `fmap` | `fmap.Fmap` | 有限集合の定義域を持つ写像 |
| `bintree` | `bintree.Tree`・`Size`・`Height`・`Occ`・`Inorder`・`Preorder` | 二分木の内容と走査モデル |

論理上の長さ・出現回数・添字は、上限のない `integer.Integer` を使う。
`seq.get/update` は `0 <= index < length`、`slice(start, stop)` は
`0 <= start <= stop <= length` を満たす範囲で使う。`stop` は範囲に含めない。
論理リストの `head/tail` は非空、`list/indexed.get(index, xs)` は範囲内の添字、
`fmap.find` は `mem(key, map)` が成立するキーを前提とする。
これらは実行時の境界検査ではなく、規定された範囲外の値は未規定。

**`runtime/*` は core のエイリアスではなく、契約付きの独立実装。**
永続データ構造を実装し、実際のコンストラクターと Why3 の
リスト・多重集合・木を再帰的なモデルで結ぶ。Stack / Queue は Why3 の LIFO / FIFO、
優先キューは最小値と重複数の仕様に対応する。Why3 の可変データ構造の抽象的な
`val` API を実行可能な実装として取り込むものではない。

core を直接呼ぶラッパーに契約を付ける方法も調査した。現在のツールチェインでは
`core/list.length`、`core/queue.peek`、`core/immut/priority_queue.push`、
`core/immut/sorted_set.contains` は契約付き関数から呼ぶと `Error 4207` になる。
`just core-capabilities` で再現でき、通常の型検査が通ることも確認する。
[MoonBit の検証仕様](https://docs.moonbitlang.com/en/latest/language/verification.html)
では契約内からの呼び出しに制限がある。`#proof_import` は論理演算の接続であり、
core の実装本体の正しさを証明するものではない。core に証明可能な契約を追加するか、
コンパイラ側で対応することが、直接再利用と実装の対応証明を両立するために必要。
`#proof_axiomatized` に置き換えて対応を仮定する方法は採用していない。


| 実行時パッケージ | 操作と表現 | 計算量 |
| --- | --- | --- |
| `runtime/list` | `empty/cons/uncons/is_empty/append/reverse/length`。不変の連結構造 | 基本操作 O(1)、連結・反転・長さ O(n) |
| `runtime/stack` | `empty/push/pop/peek/is_empty`。pop の戻り値を兼ねる連結セル | O(1) |
| `runtime/queue` | `empty/push/pop/peek/is_empty`。前方リストと逆順の後方リスト | Push/peek O(1)、pop は償却 O(1)・最悪 O(n) |
| `runtime/pqueue` | `empty/push/pop/peek/is_empty`。Int の two-pass pairing heap、重複を保持 | Push/peek O(1)、pop O(k)。k は根の子の数、最悪 O(n) |
| `runtime/bintree` | `empty/node/inorder/to_array`。汎用二分木 | 構築 O(1)、走査 O(n) |
| `runtime/bintree/search` | `empty/insert/contains`。重複のない Int の赤黒木 | Insert/contains O(log n) |

計算量は公開 API から構築した状態での実装の説明であり、形式証明の対象にはしていない。Queue は更新後の前方リストを
正規化し、繰り返しの peek で反転しない。Queue の償却計算量は、単一の
更新履歴に対するもの。古いスナップショットから分岐すると同じ処理を繰り返す場合がある。
優先キューは [pairing heap](https://www.cs.cmu.edu/~sleator/papers/Pairing-Heaps.htm) の
隣接する子を左から組にして結合し、その結果を右から結合する方式を使う。
2つの走査は末尾再帰で、停止性・内容と順序の保存を証明する。
組み合わせと結合は結果のセルを直接構築し、一時的な根の確保を省く。
赤黒木は [Okasaki の挿入アルゴリズム](https://www.cambridge.org/core/journals/journal-of-functional-programming/article/redblack-trees-in-a-functional-setting/62BC5EA75A2C95E3F6EE95AE3DADF0E5)
に基づく。core の完全二分ヒープ・サイズ平衡木とは実装が異なる。

BST の `valid(tree)` は従来と同じ厳密な探索順序を表し、`empty` が確立して `insert` が保存する。
回転を含む挿入・探索について、順序・要素の保存と検索結果を証明する。赤黒の不変条件
（黒い根、赤の連続禁止、等しい黒高さ）は shrinking 付き QuickCheck と長い昇順・降順の
テストで検査する。色の不変条件の保存と計算量の形式証明、削除は未実装。

探索木の型は、色を内部に持つ `@search.IntSet` に変更した。
`@tree.Tree[Int]` を直接渡すコードは `@search.empty()` と `insert` で構築し、列挙には
`@search.to_array(tree)` を使う。仕様側のモデルは `@tree.model` から `@search.model` に移る。
汎用の `runtime/bintree.Tree[T]` は引き続き任意形状の木に使う。
List の長さは末尾再帰、木の inorder は継続リストを使う線形走査とした。
inorder は左の枝を末尾再帰にするが、右の枝と List の append は呼び出しスタックを使う。
直接 `Tree::to_array()` は明示的な作業スタックで両方向の深い木に対応し、中間リストを
確保しない。この配列変換は独立モデルとの QuickCheck と2万段の木で検査する。
Stack/Queue/IntMinQueue/IntSet のラッパーは `#valtype`、小さな操作は `#inline` で
余分なラッパー確保を抑える。更新には `#owned` も使い、不要な参照カウント操作を減らす。
Stack は保存したセルが `(value, rest)?` そのものなので、pop で別のタプルを確保しない。
これらは実行時コードの最適化であり、既存の内容・順序の契約を変更しない。
`proof_require`・`proof_ensure`・`proof_assert` と `.mbtp` は実行時の検査ではない。

`pop/uncons/peek` は空入力に `None` を返す。リストの `length` は数学的な長さが
Int に収まること（最大 2,147,483,647）を要求し、機械整数 prelude でも確認する。
配列変換の補助関数 `from_array/to_array` は実行時の性質テストで検査し、対応の契約は
まだ付けていない。永続性が保つのはコンテナーの構造で、格納した値自体は可変の場合がある。
`examples/collections` でモジュールをまたいだ契約の合成を示し、
`just prove-collections-machine` で同じ実装と利用例を機械整数でも証明する。
