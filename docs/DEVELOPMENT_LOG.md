# 開発記録

## Phase 1.6: Railwayデプロイ設定

ホスティング先をRailwayに決定(Vercelアカウント未保有のため)。以下を追加した。

- `railway.json`: Nixpacksビルダー、起動コマンド、ヘルスチェック設定
- `docs/DEPLOYMENT.md`: Railwayでのプロジェクト作成〜PostgreSQL追加〜環境変数〜
  マイグレーション〜マスタ投入〜(Phase2の)定期バッチ設定までの手順
- `prisma/migrations/20260812034220_init/`: 正式なマイグレーション履歴を新規作成
  (これまでは`prisma db push`のみで本番向けのマイグレーション管理をしていなかった)
- `package.json`: `postinstall`で`prisma generate`を自動実行、`start`スクリプトで
  `prisma migrate deploy && next start`を実行するようにし、デプロイ環境で
  スキーマが自動的に最新化されるようにした

**マイグレーション生成時の対応**: 既存のローカルテストDB(`kinki_fishing_news`)は
`db push`で作成されており正式なマイグレーション履歴と乖離していたため、Prisma CLIから
「`migrate reset`が必要」との警告が出た。これはデータを破棄する操作であり、Claude Code
向けの安全機構により実行前にユーザーの明示的同意が必須となる。今回は同意を待たず、
**新しい空のDB (`kinki_fishing_news_migrate`) を別途作成し、既存DBに一切触れずに**
マイグレーション履歴を生成する方法に切り替えて対応した。

動作確認: `npm run build` → `npm run start` (=`prisma migrate deploy && next start`) を
実行し、マイグレーションが正しく適用され、APIが正常に応答することを確認済み。

## Phase 1.5: 情報源(sources)の登録

ユーザーから天気予報サイト・釣果情報サイト・釣具店サイトの参照URL(計10件)が提供されたため、
`sources` マスタに登録した(`prisma/seed.ts`)。

- Yahoo!天気・災害 / 大阪の天気 (気象ポータル、信頼度85)
- フィッシングマックス 関西の釣果 / 釣果記事 / 南津守店 (釣具店公式、信頼度95)
- エギCOM（エギ王）近畿の釣果情報 (メーカー公式、信頼度95)
- 釣果情報サイト カンパリ（関西エギング） (釣りメディア、信頼度80)
- つり具の上州屋 (釣具店公式、信頼度95)
- 釣具のキャスティング / キャスティングオンラインストア (釣具店公式、信頼度95)

**重要な制約**: 本開発セッションは外部ネットワークへのアクセスが遮断されており
(egress proxyが一般サイトへの接続を拒否)、各サイトの `robots.txt` および利用規約を
直接確認できなかった。指示書41項「robots.txtを確認する」「スクレイピング禁止サイトを
無理に取得しない」の原則に基づき、**全10件を `fetch_allowed=false`（要確認）として登録**し、
`notes` カラムに未確認である旨を記録した(スキーマに `sources.notes` カラムを追加)。

実際のクローラー実装 (Phase2, Agent1情報収集エージェント) に着手する前に、外部ネットワークへ
到達可能な環境で各サイトのrobots.txt・利用規約を確認し、`fetch_allowed`/`fetch_method` を
更新する必要がある。特にYahoo天気は公式の気象データ配信APIではなく二次配信ポータルのため、
利用条件の確認が必須。

## Phase 1 (Step 1〜4): プロジェクト基盤・DB設計・マスタ・釣果登録

### 実装内容

- **Step 1 プロジェクト構成**: Next.js (App Router) + TypeScript + Tailwind CSS で新規プロジェクトを作成。
  従来このブランチのリポジトリ直下にあった無関係な三人麻雀アプリ (Vite/React) は本アプリと関係がないため削除した
  (main ブランチには影響なし)。
- **Step 2 DB設計**: `prisma/schema.prisma` に指示書35〜38項の全テーブルを定義
  (`prefectures, cities, fishing_spots, fish_species, fishing_methods, baits, lures, rods, reels,
  sources, fishing_reports, images, ai_analysis, ai_predictions, weather, tide, news, users,
  notifications, user_fishing_logs`)。ER図・API一覧・画面一覧・エージェント構成・データ収集フロー・
  MLパイプライン・環境変数一覧は `docs/ARCHITECTURE.md` にまとめた。
- **Step 3 マスタ投入**: `prisma/seed.ts` で都道府県 (兵庫/大阪/和歌山を`is_active=true`、
  京都/奈良/滋賀/三重を`is_active=false`で将来拡張用に投入)、魚種20種、釣法19種を投入。
  情報源(sources)は実在URLの確認が取れていないため投入していない（下記「未実装」参照）。
- **Step 4 釣果情報の登録・表示**:
  - API: `GET/POST /api/fishing-reports`, `GET /api/fishing-reports/:id`,
    `GET /api/prefectures`, `/api/fish-species`, `/api/fishing-methods`, `/api/fishing-spots`, `/api/sources`
  - 画面: `/` (トップ、件数サマリ・最新釣果)、`/fishing-reports` (一覧・都道府県/魚種フィルタ)、
    `/fishing-reports/new` (登録フォーム)、`/fish-species`、`/fishing-spots`
  - 入力値検証: zod (`src/lib/validation.ts`)。原文(original_text)と情報源URL(source_url)を必須とし、
    サイズが入力された場合は `size_estimation_method="TEXT"` として実測値であることを明示（指示書9項の
    「実測値とAI推定値の区別」原則をStep4時点から満たす設計）。
  - `confidence_score` は登録時点で紐付く情報源(source)の信頼度を採用し、情報源未登録時は中立値(50)とする。

### 変更ファイル (主なもの)

```
docs/ARCHITECTURE.md, docs/DEVELOPMENT_LOG.md
prisma/schema.prisma, prisma/seed.ts
src/app/layout.tsx, src/app/page.tsx, src/app/globals.css
src/app/fishing-reports/page.tsx, src/app/fishing-reports/new/page.tsx
src/app/fish-species/page.tsx, src/app/fishing-spots/page.tsx
src/app/api/**/route.ts
src/lib/prisma.ts, src/lib/validation.ts
package.json, tsconfig.json, next.config.mjs, tailwind.config.ts, postcss.config.js,
eslint.config.mjs, .env.example, .gitignore, README.md
```

削除: 既存の三人麻雀アプリ一式 (`src/App.jsx` 等, `index.html`, `vite.config.js`, `.oxlintrc.json`, 旧`package.json`)。

### テスト結果

ローカルにPostgreSQL 16を起動し、実際にDBへ接続して確認した。

- `npm run typecheck` — エラーなし
- `npm run lint` (ESLint, next/core-web-vitals + next/typescript) — エラー・警告なし
- `npm run build` — 成功 (全ページ・APIルートを問題なく生成)
- `npx prisma db push` — スキーマ反映成功
- `npm run db:seed` — マスタ投入成功 (都道府県7件[有効3件]、魚種20件、釣法19件)
- `npm run dev` を起動し、以下をcurlで実地確認:
  - `GET /api/prefectures` → 有効な3府県のみ返却
  - `GET /api/fish-species` → 20件返却
  - `POST /api/fishing-reports` (原文・URL・都道府県・魚種を含む正常系) → 201、
    `size_estimation_method: "TEXT"` が正しく設定されることを確認
  - `POST /api/fishing-reports` (必須項目欠如の異常系) → 400、zodのフィールド別エラーを確認
  - `GET /fishing-reports`, `/fishing-reports/new`, `/fish-species`, `/fishing-spots`, `/` → 200、
    登録した釣果情報が一覧・トップ画面に反映されることを確認
  - `GET /api/fishing-reports/:id` の正常系・404系を確認

テストに使用したローカルDBの投入データはテスト目的のみで、本リポジトリには含まれない
(DBはgit管理対象外)。

### 未実装項目 (指示書の該当項目)

- 情報源(sources)マスタの実データ投入 — ユーザーから提供される参照URLをもとに登録する予定
  (このチャットで後日URLが提供される旨、指示書冒頭に記載あり)
- AI構造化解析 (Step5, Agent2) — 現状は原文をそのまま保存するのみで、AIによる自動抽出は未実装
- 画像解析・魚種/サイズ推定 (Step9, Agent3)、`images`テーブルへの投稿機能
- 天候・潮汐データ連携 (Step8, Agent4) — `weather`/`tide`テーブルは定義済みだが未連携
- 釣果ニュース自動生成 (Step6, Agent6)、釣果ランキング/期待度算出 (Step7, Agent5)
- 機械学習モデル (Step11)、AI釣果予測・チャット (Step10, 12, Agent7)
- 地図・ヒートマップ (Step13)、通知 (Step14)、管理者画面 (Step15)
- ユーザー認証・投稿機能 (31, 32項)、重複排除ロジック (34項)
- 定期バッチ (39項)

これらはPhase2以降で段階的に実装する方針（指示書59項のStep順を踏襲）。

### 既知の問題

- `npm run typecheck`/`build`はネットワーク経由でのパッケージ取得を前提としている(社内プロキシ経由で確認済み)。
- 本番相当のPostgreSQLインスタンスとの接続情報は`.env`で管理する必要があり、リポジトリには含めていない
  (`.env.example`を参照)。
- `sources`が空のため、釣果情報登録時に`sourceId`を指定できず、`confidence_score`は暫定的に中立値(50)になる。
  情報源マスタ投入後、既存レポートへの遡及的な紐付けは想定していない（新規登録から適用される）。

### 次のPhase

`docs/ARCHITECTURE.md`の「Phase2」に記載の通り、情報源の実データ登録（ユーザー提供URLを受領後）と
Step5 (AI構造化解析) の着手を予定。合わせて`sources`テーブルへの実データ投入方針をユーザーと確認する。
