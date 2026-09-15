# Lease の時計と single writer

[English](README.md)

[Quint でアプリケーションをモデル化した記事](https://zenn.dev/mizchi/articles/quint-application-modeling)の
2つのモデルを MoonBit に移した例。
基準は [Gist の revision 3798163 にある `lease_clock.qnt`](https://gist.github.com/mizchi/58550e8d335a532f15d8e0cd84f57231/3798163170230238b8242043898802e54e4a31c1#file-lease_clock-qnt)の
`vulnerable_lease_clock` と `bounded_skew_candidate`。
これらの意味をモデル化する。celld や Rust の実装には接続しない。

## 実行

リポジトリ直下で実行する。MoonBit・Node.js 24以上・Z3・just が必要。

```sh
just lease-clock          # Z3、有限状態の全探索、MoonBit での反例再生
just test-lease-clock     # 独立実装との照合、shrinking、4バックエンド
just verify-lease-clock   # フォーマットとコンパイルの検査も含む
just apalache-lease-clock # 任意：Nix で Apalache 0.62.2 と Java 21 を用意
```

結果は `_build/lease-clock/report.json`、Apalache も使った場合は
`apalache-report.json` に保存する。各レポートに実行ごとの新しいディレクトリを記録し、
JSON の遷移表・TLA+・SMT 制約・Apalache の ITF 形式の反例を残す。

## 状態と操作

定数は元の Quint と同じ。ノードは A/B の2個、cell は1個、TTL は3 tick、
壁時計のずれは A=0・B=1、全体の時刻の上限は6。
各ノードが公開した lease の期限、更新後の単調時計の経過時間、lease の保持状態、
ローカルで公開済みの epoch を持つ。共有する owner とその epoch は、各ノードの
ローカルな epoch と別に保持する。所有権の変更は1つの原子的操作で、元モデルの CAS の仮定に対応する。

型は [types.mbt](types.mbt)、不変な状態更新は [model.mbt](model.mbt) に分離した。
`step` はガードを満たさない操作に `None` を返し、`replay` はその操作を含む列を拒否する。
入力は `initial()` とこれらの遷移から生成した状態を想定する。

| 規則 | `Vulnerable` | `BoundedSkew` |
| --- | --- | --- |
| 書き込み可否 | lease を保持し、公開済み epoch がある | さらに経過時間 `< TTL` を毎回確認 |
| 更新 | lease を保持している | さらに経過時間 `< TTL` が必要 |
| Fence | 経過時間 `> TTL` | 経過時間 `>= TTL` |
| 所有権の取得 | 取得側の壁時計で旧 owner の期限切れを判定 | ずれの1 tick 分待ち、取得側自身の有効性も確認 |
| Owner の公開 | lease を保持し、未公開の epoch がある | さらに自身の lease の有効性を確認 |

イベントは `AdvanceTime`、`RenewNodeLease(node)`、`FenceExpiredNode(node)`、
`TakeOver(node)`、`PublishCurrentOwner`。ノードを取る操作は A/B の両方を列挙し、
合計8個の選択肢を探索する。人工的な待機イベントは加えない。

## 決定的な2つの例

`"mizchi/veri-examples/lease_clock"` を import して利用する。
テストでは `@lease_clock` として参照する。

```moonbit
let state = @lease_clock.replay(Vulnerable, @lease_clock.initial(), [
  AdvanceTime, AdvanceTime, TakeOver(B), PublishCurrentOwner,
]).unwrap()
assert_false(@lease_clock.single_writer(Vulnerable, state))
```

時刻2で B の壁時計は3となり、A が公開した期限3を期限切れと判断する。
A は lease と epoch 1 を保持したまま。B の epoch 2 を公開すると2個の writer が成立する。
修正モデルでは、この時点の所有権取得は拒否される。

```moonbit
let state = @lease_clock.replay(BoundedSkew, @lease_clock.initial(), [
  AdvanceTime, RenewNodeLease(B), AdvanceTime, AdvanceTime,
  TakeOver(B), PublishCurrentOwner,
]).unwrap()
assert_true(@lease_clock.single_writer(BoundedSkew, state))
assert_true(@lease_clock.may_write(BoundedSkew, state, B))
```

時刻3なら B が引き継げる一方、A は毎回の単調時計による判定で書き込みを拒否する。
A に古い epoch が残っていても書き込み権限はない。
期限切れの A を更新で復活させることも修正モデルは拒否する。

## 検査結果と保証範囲

| 検査 | 結果 |
| --- | --- |
| 脆弱モデル・深さ3 | その範囲では反例なし |
| 脆弱モデル・深さ8 | 最短の安全性違反は4操作 |
| 修正モデル・深さ8 | 反例なし。Z3 と Apalache で一致 |
| 修正モデルで B が書き込み可能になるか | 6操作で到達。すべてを禁止しただけの修正ではないことを確認 |
| 修正モデルの有限な到達状態全体 | 470状態すべてで single writer。最短到達距離の最大は14操作 |

脆弱モデルは深さ8で445状態、183状態でその先の遷移を省略する。
時刻に上限があっても epoch に上限はない。時刻4で両ノードが fence されずに残れば、
公開せずに所有権だけを交互に取得し続けられる。
実行時の epoch が Int の表現上限に達したら検査を中止する。桁あふれ、飽和、
操作を黙って無効化する処理で元モデルの意味を変えない。

再利用可能な [探索器](../../model_check/explore.mbt) は、最短到達距離・遷移を省略した
境界の状態・到達状態全体を探索できたかを記録する。
指定した深さ以内の実行に必要な遷移はすべて保存する。
別に設けた状態数の資源上限を超えた場合は検査を中止する。
Z3/TLA+ への変換では、未完了の探索に対する深さ超過や活性の検査を拒否する。
省略した辺を自己ループに置き換えることはしない。
元モデルの行き止まりや探索の境界を安全性違反と扱わないため、
この例の安全性・到達性検査では Apalache の deadlock 検査を無効にする。

修正モデルは深さ16までの探索で到達状態全体を調べ終える。
その全状態を検査した結果は、自己ループを含む**この有限モデルの任意長の実行**を対象とする。
これは SMT の深さ8の結果とは区別する。時刻の上限、ノード2個、固定された時計差という
前提は残る。任意の時計値やノード数について `moon prove` で帰納的に証明したものではない。

出力された全状態・ガード・遷移・述語・探索の境界を、独立した命令的な実装と照合する。
1,000件の QuickCheck では標準の配列 shrinking を使う。
TTL と等しい境界、不正な操作、期限切れの更新、epoch の増加、不正な再生証明書も検査する。
ソルバの実行列は、出力済みの表を使うだけでなく MoonBit の `step` を再実行する。
モデル・探索器・変換処理・テストによる実行可能な検査であり、celld の実装との対応や
スケジューラの公平性はここでは仮定しない。
