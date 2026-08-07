# server

Serverpod製サーバー。オンライン対戦（ランダムマッチ・友人戦・レート・段位・再接続）とアカウント機能の権威側。

| ディレクトリ | 役割 |
|---|---|
| `lib/src/endpoints` | RPCエンドポイント（matchmaking / rooms / match / session。STEP4「通信設計」参照） |
| `lib/src/authoritative` | `mahjong_engine`を使った権威判定（クライアントの申告を再検証） |
| `lib/src/matchmaking` | Redis連携のマッチングキュー・ルーム状態・再接続トークン |
| `migrations` | PostgreSQLマイグレーション（STEP3「DB設計」のテーブル定義） |

現時点ではディレクトリ構成のみ（STEP6）。実際の`serverpod create`によるプロジェクト雛形生成と実装はSTEP9・STEP10で行う。
