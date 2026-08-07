# 三人麻雀アプリ

スマートフォン向け（iOS / Android）三人麻雀アプリ。CPU戦・オンライン対戦・友人戦の3モードに対応し、複数の特殊麻雀ルール（ルールセット）を切り替えて遊べる構成を目指す。

- クライアント: Flutter
- サーバー: Serverpod（オンライン対戦・アカウント・レート・段位）
- ルールエンジン: `packages/mahjong_engine`（純Dart、クライアント/サーバー共有）

最初のルールセットは「6華6北5等三麻（SixKa6PeiSanma）」。詳細は [`docs/design/`](./docs/design/00-overview.md) を参照。

## リポジトリ構成

```
packages/mahjong_engine/   麻雀ルールエンジン（純Dart）
packages/shared_protocol/  クライアント/サーバー共有DTO
apps/mobile/                Flutterクライアント
server/                      Serverpodサーバー
docs/design/                 設計ドキュメント（STEP1〜10）
docs/legacy/                 旧Webアプリ（別ルール、アーカイブのみ）
```

詳しい設計判断は [`docs/design/00-overview.md`](./docs/design/00-overview.md) から辿れる。

## 開発状況

設計フェーズ（STEP1〜6完了）。実装（STEP10）はFlutter/Dart/Serverpodのツールチェーンが使える環境で行う。
