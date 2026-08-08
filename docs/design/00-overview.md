# 設計ドキュメント インデックス

三人麻雀アプリ開発の10ステップのうち、STEP1〜7の確定内容をここにまとめる。各ファイルは議論の過程ではなく**最終的に確定した仕様**を記載する。

| STEP | ファイル | 内容 |
|---|---|---|
| 1 | [01-tech-stack.md](./01-tech-stack.md) | 技術選定（Flutter / Dart / Serverpod） |
| 2 | [02-system-architecture.md](./02-system-architecture.md) | システム構成図 |
| 3 | [03-database-design.md](./03-database-design.md) | DB設計（段位廃止・難易度連動レート反映済み） |
| 4 | [04-communication-design.md](./04-communication-design.md) | 通信設計 |
| 5 | [05-mahjong-rules-six-ka-six-pei-sanma.md](./05-mahjong-rules-six-ka-six-pei-sanma.md) | 麻雀ルール設計（SixKa6PeiSanmaルールセット） |
| 6 | [06-directory-structure.md](./06-directory-structure.md) | ディレクトリ構成 |
| 7 | [07-ui-design.md](./07-ui-design.md) | UI設計 |
| 追補 | [08-anomaly-detection-pipeline.md](./08-anomaly-detection-pipeline.md) | 異常検知ボタン・Claude Codeによる自動バグ判定パイプライン |
| 8〜10 | 未着手 | CPU思考アルゴリズム / オンライン設計 / 実装 |

## 段位の廃止とレートの再定義

段位（ELO的な持続スコア）は廃止した。プレイヤーが選ぶのは**難易度**（簡単/中/難）のみで、「レート」（0.5/100/200）は難易度に紐づいて自動的に決まる祝儀の倍率。詳細はSTEP3参照。

## 前提：複数ルールセット対応

このアプリは「6華6北5等三麻（SixKa6PeiSanma）」を最初の1つとして、将来的に複数の特殊麻雀ルールを追加できる構成にする。`packages/mahjong_engine`内の`RulesetDefinition`抽象インターフェースに対して、ルールセットごとにプラグインとして実装を追加する（詳細は05を参照）。
