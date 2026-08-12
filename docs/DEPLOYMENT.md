# デプロイ手順 (Railway)

指示書49項の推奨構成(Vercel+Supabase)から、ホスティング先を **Railway** に変更して運用する。
Next.jsアプリ・PostgreSQLを1アカウントでまとめて管理できるため。

## 1. プロジェクト作成

1. [railway.app](https://railway.app) にアクセスし、GitHubアカウントでサインアップ/ログイン
2. 「New Project」→「Deploy from GitHub repo」で `MasakiTanimizu/Claudecode-` を選択
3. デプロイ対象ブランチを指定 (本番運用ブランチ。開発中は `claude/fishing-news-ai-app-nagp0j` でも可)

Railwayは `railway.json` (本リポジトリに追加済み) を検出し、Nixpacksビルダーでビルドする。
ビルドコマンド・起動コマンドはpackage.jsonの`scripts`から自動検出されるが、
`railway.json`で`startCommand: "npm run start"`を明示している。

## 2. PostgreSQLの追加

1. 同一プロジェクト内で「+ New」→「Database」→「Add PostgreSQL」
2. Postgresサービスが作成されると `DATABASE_URL` 等の接続情報が自動生成される
3. アプリ側サービスの Variables に以下を追加:
   - `DATABASE_URL` = `${{Postgres.DATABASE_URL}}` (Railwayのサービス参照変数)
   - `NEXT_PUBLIC_APP_NAME` = `近畿釣果ニュースAI`

## 3. マイグレーション

`npm run start` は `prisma migrate deploy && next start` を実行するため、
デプロイ(再起動含む)のたびに `prisma/migrations/` の未適用分を自動適用する。
手動で実行したい場合は Railway CLI を使う:

```bash
railway link       # プロジェクトを紐付け
railway run npx prisma migrate deploy
```

## 4. マスタデータ投入 (初回のみ)

```bash
railway run npm run db:seed
```

冪等な `upsert` で実装されているため、再実行しても重複しない。

## 5. 定期バッチ (Phase2以降, 指示書39項)

情報収集・AI解析・ニュース生成などの日次バッチは、以下のいずれかで定期実行する:

- **Railway Cron Job**: 同一プロジェクトに「Cron Job」タイプのサービスを追加し、
  スケジュール実行させる (例: 毎日05:00 JST → UTCで `0 20 * * *`)
- **GitHub Actions scheduled workflow**: `.github/workflows/`にcronトリガーを定義し、
  デプロイ済みAPIのエンドポイント (例: `/api/cron/collect`) を `CRON_SECRET` ヘッダー付きで呼び出す

いずれの方式でも、バッチ本体はNext.jsアプリのAPI Routeとして実装し、認証されていないリクエストを
拒否する (指示書42項)。現時点ではバッチ本体は未実装 (Phase2で着手)。

## 6. robots.txt自動チェック (情報源の取得可否確認)

`sources`に登録した情報源は、robots.txtが未確認のため `fetch_allowed=false` のまま登録されている
(`docs/DEVELOPMENT_LOG.md` Phase1.5参照)。本開発サンドボックスは外部ネットワークに到達できず
robots.txtを確認できないため、Railway上(実際にインターネットへ到達できる環境)で
以下のエンドポイントを1回呼び出すことで、robots.txtに基づいた自動判定を行う。

```bash
curl -X POST https://<railwayのアプリURL>/api/sources/verify-robots \
  -H "x-admin-secret: <ADMIN_API_SECRETの値>"
```

このエンドポイントは各情報源のrobots.txtを取得し、対象URLへのアクセスが許可されているかを
判定して `fetch_allowed` / `fetch_method` / `notes` を更新する。**robots.txtの技術的判定のみ**
を行うものであり、著作権・利用規約の遵守(指示書41項)については別途人手での確認が必要である
旨を`notes`に記録する。

`ADMIN_API_SECRET` が未設定の場合、このエンドポイントは常に503を返して無効化される
(安全側のデフォルト)。将来、指示書33項の管理者画面が実装された際にこの認証方式を置き換える。

## 7. 環境変数まとめ

`.env.example` を参照。Railway上では以下を設定する:

| 変数名 | 値の例 | 備考 |
|---|---|---|
| `DATABASE_URL` | `${{Postgres.DATABASE_URL}}` | Railway PostgreSQLプラグインの参照変数 |
| `NEXT_PUBLIC_APP_NAME` | `近畿釣果ニュースAI` | |
| `ADMIN_API_SECRET` | (ランダムな文字列を生成) | `/api/sources/verify-robots` 保護用 |
| `CRON_SECRET` | (Phase2で追加) | 定期バッチAPIの認証用シークレット |

APIキー等の秘密情報は`NEXT_PUBLIC_`を付けず、フロントエンドに露出しないようにする(指示書42項)。
