# STEP6: ディレクトリ構成

Melosモノレポ構成。`packages/mahjong_engine`を中心に、クライアント（Flutter）とサーバー（Serverpod）が同じルールエンジンを参照する。

```
/
├── melos.yaml
├── packages/
│   ├── mahjong_engine/            純Dart。Flutter/Serverpod非依存
│   │   └── lib/src/
│   │       ├── core/               牌・手牌・面子などの共通モデル
│   │       ├── rulesets/
│   │       │   ├── ruleset_definition.dart
│   │       │   ├── ruleset_registry.dart
│   │       │   └── six_ka_six_pei_sanma/   1つ目の具体ルールセット
│   │       ├── engine/             ターン進行・合法手判定の状態機械
│   │       ├── scoring/            符・翻計算、固定点数表、ウマ清算
│   │       ├── replay/             match_eventsを再生して盤面復元
│   │       └── ai/                 CPU思考（STEP8）
│   └── shared_protocol/            クライアント/サーバー共有DTO
├── apps/
│   └── mobile/                     Flutterクライアント
│       └── lib/
│           ├── app/                 ルーティング・DI初期化
│           ├── presentation/        UI層（screens / widgets / view_models）
│           ├── domain/              オフラインCPU戦のユースケース
│           └── data/                local(Drift) / remote(Serverpod)
├── server/                          Serverpodサーバー
│   └── lib/src/
│       ├── endpoints/               matchmaking / rooms / match / session
│       ├── authoritative/           mahjong_engineを使った権威判定
│       └── matchmaking/             Redis連携のキュー・再接続
├── docs/
│   ├── design/                      設計ドキュメント（このディレクトリ）
│   └── legacy/                      旧Webアプリ（チューリップ祝儀ルール版）のアーカイブ
└── .github/workflows/               CI
```

## 主な配置ルール

- **mahjong_engineの独立性**: Flutter・Serverpodへの依存を一切持たない。`apps/mobile`と`server`の両方から利用されることで、STEP2の「ロジック完全共有」を保証する
- **新ルールセットの追加方法**: `rulesets/`配下に新しいディレクトリを1つ追加し、`ruleset_registry.dart`に登録するだけで済む構成
- **UIとロジックの境界**: `presentation/view_models`が唯一`mahjong_engine`と`data`層の両方を知るレイヤー。`screens/widgets`は状態を受け取って描画するだけにする
- **四人麻雀への将来拡張**: `rulesets/`に4人打ち用のルールセットを追加するだけで対応可能。`core/`・`engine/`は人数を固定値として扱わない

## 現在の状態（STEP6時点）

ディレクトリ構成と`melos.yaml` / 各パッケージの`pubspec.yaml`のみ作成済み。Flutter/Dartのツールチェーンがこの環境に無いため、`flutter create` / `serverpod create`によるプラットフォーム雛形生成（ios/ android/ 等）と実際の実装はSTEP10で、該当ツールチェーンが使える環境で行う。

旧Webアプリ（`src/App.jsx`ほか）は`docs/legacy/`へ移動済み。
