# mahjong_engine

Pure-Dart麻雀ルールエンジン。Flutter・Serverpodのどちらにも依存しない（`packages/mahjong_engine/pubspec.yaml`参照）。

- `apps/mobile` からはオフラインCPU戦・リプレイ再生のために直接呼び出される
- `server` からはオンライン対戦の権威判定のために呼び出される

同じロジックを両方から呼ぶことで、クライアントとサーバーでルール判定がズレる問題を構造的に防ぐ（`docs/design` STEP1・STEP2参照）。

## レイヤー

| ディレクトリ | 役割 |
|---|---|
| `src/core` | 牌・手牌・面子など、ルールセットに依存しない共通モデル |
| `src/rulesets` | `RulesetDefinition`抽象インターフェースと、その実装群（プラグイン構造。STEP5補遺参照） |
| `src/engine` | ターン進行・合法手判定の状態機械 |
| `src/scoring` | 符・翻計算、固定点数表、ウマ清算 |
| `src/replay` | `match_events`（DB STEP3）を再生して盤面を復元 |
| `src/ai` | CPU思考アルゴリズム（STEP8で設計） |

現時点ではディレクトリ構成のみ（STEP6）。実装はSTEP10で行う。
