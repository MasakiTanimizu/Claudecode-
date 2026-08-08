# server

Serverpod製サーバー。オンライン対戦（ランダムマッチ・友人戦・レート・段位・再接続）とアカウント機能の権威側。

| ディレクトリ | 役割 |
|---|---|
| `lib/src/endpoints` | RPCエンドポイント（matchmaking / rooms / match / session。STEP4「通信設計」参照） |
| `lib/src/authoritative` | `mahjong_engine`を使った権威判定（クライアントの申告を再検証） |
| `lib/src/matchmaking` | Redis連携のマッチングキュー・ルーム状態・再接続トークン |
| `migrations` | PostgreSQLマイグレーション（STEP3「DB設計」のテーブル定義） |

## 現在の状態（STEP10進行中）

`lib/src/authoritative/`（`match_action.dart` / `action_validator.dart`）を実装済み。クライアントの申告（`MatchAction`）を`mahjong_engine`の`GameState`に適用し、正当性を再検証する層で、Serverpod非依存の純Dartパッケージとしてテスト済み（`test/`, CI: `server-ci.yml`）。

`lib/src/endpoints` / `lib/src/matchmaking` / `migrations`は未着手。これらの実装には実際の`serverpod create`によるプロジェクト雛形生成（`.spy.yaml`プロトコル定義→`serverpod generate`によるコード生成）とPostgreSQL/Redisが必要で、このサンドボックスには無い専用ツールチェーン。該当ツールチェーンが使える環境で行う。
