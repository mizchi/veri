# SMT-LIB 2 の項と実行時の値

[English](smtlib.md) | [README](../README.ja.md)

`mizchi/veri/smtlib` は SMT-LIB 2 の項を構築・出力・解析・評価し、MoonBit の実行時の値と
SMT の値を双方向に対応づける。証明用バインディングを補うもので、`bitvector`・`arrays`・
`strings`・`ieee754` が `moon prove` 向けに名前を与えている理論を、通常の実行時データとして扱う。

```text
実行時の値 ──Encode──▶ Value ──▶ Context 内の Term ──Script──▶ ソルバー
     ▲                   ▲            │ eval                     │
     └───── decode ──────┴────────────┴── parse_values / parse_model
```

全バックエンドで動作し、このモジュール以外に依存しない。
`mizchi/veri/smtlib/solver` はソルバーのプロセスを扱うため、native と wasm だけに対応する。

## ソートと実行時の型

| ソート | `Value` | `Encode` で対応する実行時の型 |
| --- | --- | --- |
| `Bool` | `Boolean` | `Bool` |
| `Int` | `Integer` | `BigInt` |
| `(_ BitVec n)`、`1 <= n <= 64` | `Bits(n, bits)` | `Byte`（8）、`UInt16`（16）、`UInt` / `Int`（32）、`UInt64` / `Int64`（64） |
| `String` | `Text` | `String`。U+0000..U+2FFFF の整形式 UTF-16 |
| `(_ FloatingPoint 8 24)` / `11 53` | `F32` / `F64` | `Float` / `Double` |
| `(Array K V)` | `Table` | セル列は `array_value`、`Map[K, V]` は `map_value` |

機械整数はその幅のビットベクタになるので、`UInt` 上の項は実行時と同じように wrap する。
これは証明で `runtime/uint32.model`・`runtime/uint64.model` が使う符号化と同じ。
`Int` と `UInt` は同じ32ビットを共有し、符号の解釈は値ではなく演算（`bv_slt` か `bv_ult`）が決める。
上限のない `Int` ソートには `BigInt` を使う。

浮動小数点は IEEE のビット列で、NaN はすべて1つに正規化する（SMT-LIB の NaN は1つだけ）。
配列の値は全域写像で、`array_value(cells, default~)` は添字 `0..cells.length()` に `cells` を、
それ以外に `default` を置く。実行時のセルを表すのはこの範囲だけで、`runtime/array.model` と同じ規約。
`Value::to_fixed_array(length)` でこの範囲を読み戻す。

## 項の構築と評価

項は `Context` の中に作る。各コンストラクタがオペランドのソートを検査して `SortMismatch` を
raise するので、ソートの合わないスクリプトはソルバーに渡る前に拒否される。
完全な例は `examples/midpoint` にある。

```moonbit
// mizchi/veri/smtlib を import する。
test {
  let ctx = @smtlib.Context::new()
  let low : @smtlib.Typed[UInt] = ctx.typed("low")
  let high : @smtlib.Typed[UInt] = ctx.typed("high")
  // (_ BitVec 32) 上の (low + high) / 2
  let middle = ctx.bv_udiv(ctx.bv_add(low.term, high.term), ctx.literal(2U))

  let inputs = @smtlib.Model::new()
  inputs.bind(low, 0xf000_0000U)
  inputs.bind(high, 0xffff_ffffU)
  let value : UInt = ctx.eval_as(middle, inputs)
  assert_eq(value, (0xf000_0000U + 0xffff_ffffU) / 2U) // どちらも wrap して 0x77ffffff
}
```

項はハッシュコンシングされる。同じ構造を2回作ると同じハンドルが返り、項の `==` は整数比較になり、
複数回使われる部分項は `let` の下に1回だけ出力される。走査は明示的なスタックで行うため、
深さ10万の項も再帰なしで出力・評価できる。

`Context::eval` は、機械の挙動と異なる箇所では SMT-LIB 2 に従う。

| 演算 | 結果 |
| --- | --- |
| ゼロによる `bv_udiv` / `bv_urem` | 全ビット1 / 被除数 |
| 最小値を -1 で割る `bv_sdiv` | 最小値 |
| 幅以上のシフト | ゼロ。`bv_ashr` は符号ビットで埋める |
| `int_div` / `int_mod` | ユークリッド除算で余りは非負。ゼロ除算は `Unspecified` |
| 文字列の位置と長さ | UTF-16 単位ではなくコードポイント |
| 浮動小数点の `eq` | `NaN = NaN`、`+0 ≠ -0`。`fp_eq` は IEEE の等値 |
| 浮動小数点演算 | 最近接偶数への丸め |

結果が整数のゼロ除算、またはモデルにない定数に依存する場合は `Unspecified` を raise する。
ただし `and`・`or`・`=>`・`ite` が他のオペランドだけで結果を決められる場合は値を返す。

## スクリプトとソルバーの応答

`Script` がコマンドを書き出す。定数は最初に使う前に自動で宣言され、`push` / `pop` は
ソルバー側と同じようにその宣言も取り消す。

```moonbit
// claim: `low <= high` ならば `low <= middle <= high`。bv_ule / and_ / implies で構築
let script = @smtlib.Script::new(ctx, logic="QF_BV")
script.assert_term(ctx.not_(claim))
script.check_sat()
script.get_value([low.term, high.term])
// script.to_string():
// (set-logic QF_BV)
// (declare-const low (_ BitVec 32))
// (declare-const high (_ BitVec 32))
// (assert (let (($t4 (bvudiv (bvadd low high) #x00000002)))
//   (not (=> (bvule low high) (and (bvule low $t4) (bvule $t4 high))))))
// (check-sat)
// (get-value (low high))

let values = ctx.parse_values("((low #xf0000000)\n (high #xffffffff))", [low.term, high.term])
let found : UInt? = values[0].decode() // Some(0xf0000000)
```

`parse_values` は `get-value` の応答を要求した各項のソートに従って復号し、`parse_model` は
`get-model` の応答を復号する。どちらも Z3 の出力形式を受け付ける。`#x` / `#b` / `(_ bvN w)`、
`(- n)`、文字列のエスケープ、`(fp ...)` と名前つきの浮動小数点定数、`as const` 上の `store` の連鎖、
`let` で省略された値、`(= x リテラル)` による場合分けの `lambda` で表された配列。
それ以外は `Malformed` か `Unsupported` を raise し、モデルを部分的に復号して返すことはない。

PATH 上にソルバーがあれば、`smtlib/solver` がクエリを実行する（native と wasm）。

```moonbit
// mizchi/veri/smtlib/solver を import する。
async fn find_inverse() -> UInt {
  let ctx = @smtlib.Context::new()
  let x : @smtlib.Typed[UInt] = ctx.typed("x")
  let inverse = ctx.eq(ctx.bv_mul(x.term, ctx.literal(0x9e37_79b1U)), ctx.literal(1U))
  guard @solver.check(ctx, [inverse]) is Satisfiable(model) else { abort("no inverse") }
  model.read(x).unwrap() // 0x9e3779b1 を掛けるとネイティブ演算でも 1 になる
}
```

`with_session` は1つのプロセスを保持し、インクリメンタルに使える。`Session::check_sat`、
`Session::values`、生のコマンド用の `Session::send` / `line` / `response` がある。
タイムアウト、メモリ、入出力量の上限を強制し、コールバックが失敗するとプロセスを終了させる。
モデル検査のランナーも同じセッションを使う。

## 証明用バインディングと共通の名前

| 証明用バインディング（Why3） | `smtlib` の項 | SMT-LIB 2 |
| --- | --- | --- |
| `Bv32::add/sub/mul/udiv/urem/sdiv/srem` | `bv_add` … `bv_srem` | `bvadd` … `bvsrem` |
| `Bv32::bw_and/bw_or/bw_xor/bw_not`、`neg` | `bv_and/bv_or/bv_xor/bv_not`、`bv_neg` | `bvand` … `bvneg` |
| `Bv32::shl/lshr/ashr`、`ult/ule/slt/sle` | `bv_shl` … `bv_sle` | `bvshl` … `bvsle` |
| `to_bv8` … `to_bv64` | `bv_extract`、`bv_zero_extend`、`bv_sign_extend`、`bv_concat` | `extract`、`zero_extend`、`sign_extend`、`concat` |
| `of_integer` / `to_integer` | `int_to_bv` / `bv_to_int` | `int2bv` / `bv2nat` |
| `arrays.select/store/const_array` | `select` / `store` / `const_array` | `select` / `store` / `as const` |
| `strings.concat/length/char_at/substring` | `str_concat/str_length/str_at/str_substr` | `str.++`、`str.len`、`str.at`、`str.substr` |
| `strings.contains/prefix_of/suffix_of/index_of/replace` | `str_contains` … `str_replace` | `str.contains` … `str.replace` |
| `strings.to_integer/from_integer/lt/le` | `str_to_int/str_from_int/str_lt/str_le` | `str.to_int`、`str.from_int`、`str.<`、`str.<=` |

証明用バインディングと `smtlib` は別物で、`Term` は証明上の `Bv32` ではない。
`moon prove` がここにあるものを仮定することもない。

## 検査している内容

- 4バックエンドの単体テストで、境界値に偏らせた乱数入力について、評価結果をネイティブの
  `UInt`・`Int`・`UInt64`・`Int64`・`Byte`・`Float`・`Double` の演算、および証明済みの
  `runtime/uint32`・`runtime/uint64` の `add` / `sub` / `less` と比較する。
- `just smtlib` は `cmd/smtlib-check` を Z3 に対して実行する。全ソート・全演算にわたる
  ソートの合った項を乱数で生成する。閉じた項は `項 = 値` を証明する（否定が `unsat`）。
  定数を含む項は、定数を乱数値として定義し、各項を `get-value` で読み戻して評価器と比較する。
  さらに6個の固定クエリを解き、得られたモデルをネイティブ演算で確認する。
  既定の200ラウンドで約12,000項を検査する。SMT-LIB が値を定めない項は除外し、件数を表示する。
  Z3 が10秒以内に `unknown` を返した主張は失敗ではなく未決定として数える。失敗になるのは
  `sat`（実際の不一致）だけで、未決定が全体の2%を超えた場合も失敗とする。
- モデル検査のエンコーダ出力は、以前の実装から取ったスナップショットでバイト単位に固定している。

## 制限

- 対象は量化子なしの断片で、未解釈関数、実数、正規表現、64ビットを超えるビットベクタは扱わない。
- 浮動小数点演算は最近接偶数への丸めだけ。浮動小数点のビット列を取り出す項はない
  （SMT-LIB にその関数がない）。
- 対にならないサロゲートを含む文字列、またはそれを必要とするソルバーのモデルは拒否する
  （MoonBit の文字列で表せない）。
- 評価器は差分検査の対象であり、証明はしていない。Z3 との一致は生成した項に対する証拠で、
  すべての項についての定理ではない。
- ソルバーの結果の信頼性はソルバーに依存する。`unknown` やタイムアウトは何も決定しない。

計測結果とその限界は[ベンチマーク](benchmarks.ja.md#smt-lib-のベンチマーク)を参照。
