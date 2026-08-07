# STEP1: 技術選定

## 方針

クライアントとサーバーを両方Dartで実装し、麻雀ルールエンジンを1つの純Dartパッケージ（`packages/mahjong_engine`）として共有する。ロジックの二重実装によるクライアント/サーバー間の不整合を構造的に防ぐため。

## クライアント（iOS / Android）

| 項目 | 選定 |
|---|---|
| フレームワーク | Flutter |
| 言語 | Dart |
| 状態管理 | Riverpod |
| 牌アニメーション | Flutter標準アニメーション + `CustomPainter` |
| ローカル永続化 | Drift（SQLite） |
| 通信 | Serverpod生成クライアント（WebSocketベース） |
| Lint | very_good_analysis |

## サーバー（オンライン対戦・アカウント）

| 項目 | 選定 |
|---|---|
| フレームワーク | Serverpod（Dart製フルスタックFW） |
| DB | PostgreSQL |
| キャッシュ/マッチング状態 | Redis |
| 認証 | Serverpod Authモジュール（Google / Apple / ゲスト） |
| リプレイ保存 | 着手イベントをJSON配列としてPostgres/オブジェクトストレージに保存 |

## モノレポ・CI/CD・テスト

- モノレポ管理: Melos
- 単体テスト: `test`（mahjong_engineの役判定・点数計算等）
- 統合テスト: `flutter_test` + `mocktail`、`integration_test`
- CI: GitHub Actions
- ストア配信: Fastlane
- クラッシュ解析: Firebase Crashlytics（任意）

## 不採用にした代替案

- React Native + Node.js: 既存資産（旧Webアプリ）はJSだが、クライアント/サーバーで言語が分かれロジック二重実装のリスクが残るため不採用
- Node.js(TypeScript) + NestJS + Prisma + Socket.io: エコシステムは豊富だが同様の理由で不採用
- Goサーバー: 同時接続性能は高いが、Serverpodほど認証・ORM・型安全クライアント生成を即座にカバーできないため不採用
