# apps/mobile

Flutterクライアント（iOS / Android）。

## レイヤー

| ディレクトリ | 役割 |
|---|---|
| `lib/app` | ルーティング・DI初期化 |
| `lib/presentation/screens` | 対局・ロビー・設定・友人戦ルームなどの画面 |
| `lib/presentation/widgets` | 牌・卓・アニメーション部品（STEP7「UI設計」） |
| `lib/presentation/view_models` | Riverpod Notifier。`mahjong_engine`とUIの境界 |
| `lib/domain` | オフラインCPU戦で`mahjong_engine`を直接呼ぶユースケース |
| `lib/data/local` | Drift（設定・オフライン戦績・リプレイキャッシュ） |
| `lib/data/remote` | Serverpod生成クライアントの呼び出し |

現時点ではディレクトリ構成のみ（STEP6）。実際の`flutter create`によるプラットフォーム（ios/ android/）雛形生成と実装はSTEP10で、Flutter SDKが使える環境で行う。
