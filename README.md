# 近畿釣果ニュースAI

兵庫県・大阪府・和歌山県の釣果情報を収集・分析し、毎日最新の釣果ニュースを配信するAI搭載の釣り情報アプリ（開発中）。

最終目標や詳細な機能要件は `docs/ARCHITECTURE.md` と `docs/DEVELOPMENT_LOG.md` を参照してください。
デプロイ手順(Railway)は `docs/DEPLOYMENT.md` を参照してください。

## 技術構成

- Next.js (App Router) / TypeScript / Tailwind CSS
- PostgreSQL + Prisma
- zod による入力値検証

## セットアップ

```bash
npm install
cp .env.example .env   # DATABASE_URL を設定
npm run db:generate
npm run db:push        # 開発用: マイグレーションファイルなしでスキーマ反映
npm run db:seed        # マスタデータ (都道府県/魚種/釣法) を投入
npm run dev
```

## 開発コマンド

```bash
npm run dev        # 開発サーバー起動
npm run build       # 本番ビルド
npm run lint         # ESLint
npm run typecheck    # 型チェック
npm run db:studio    # Prisma Studio (DBブラウザ)
```

## 現在の実装範囲 (Step 1〜4)

- プロジェクト構成 (Next.js + TypeScript + Tailwind + Prisma)
- DB設計 (`prisma/schema.prisma`) — 指示書35〜38項の全テーブルを定義
- マスタデータ: 都道府県 (兵庫/大阪/和歌山を有効化)、魚種、釣法
- 釣果情報の登録・一覧表示 (`/fishing-reports`, `/fishing-reports/new`)

詳細は `docs/DEVELOPMENT_LOG.md` を参照してください。AI解析・釣果予測・機械学習・地図・通知・管理画面等はPhase2以降で実装予定です。
