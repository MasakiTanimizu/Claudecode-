# STEP3: DB設計

## テーブル一覧

### users — アカウント
`id` / `auth_provider`(google, apple, guest) / `external_id` / `display_name` / `avatar_url` / `is_guest` / `created_at`

### player_stats — 累積成績
`user_id`(PK/FK) / `rating` / `dan_tier_id`(FK) / `dan_points` / `games_played` / `rank_sum` / `top_count` / `last_played_at`

### dan_tiers — 段位マスタ（参照テーブル）
`id` / `name` / `min_points` / `demote_points` / `sort_order`

段位のしきい値や段位数をコード変更なしで運用できるようにするための参照テーブル。

### rating_history — レート増減ログ
`id` / `user_id`(FK) / `match_id`(FK) / `rating_delta` / `dan_points_delta` / `final_rank` / `created_at`

### friends — フレンド関係
`user_id`(FK) / `friend_id`(FK) / `status`(pending, accepted, blocked) / `created_at`（複合PK: user_id, friend_id）

### rooms — 友人戦ルーム
`id` / `room_code`(unique, 6桁) / `host_user_id`(FK) / `rule_settings_id`(FK) / `ruleset_key` / `status`(waiting, in_progress, finished) / `allow_spectate` / `created_at`

### room_members — 入室者
`room_id`(FK) / `user_id`(FK) / `seat` / `is_ready` / `is_spectator`（複合PK: room_id, user_id）

### rule_settings — ルールプリセット
`id` / `owner_user_id`(nullable, null=運営提供の既定プリセット) / `ruleset_key`（どの`RulesetDefinition`実装を使うか） / `name` / `config`(jsonb, そのルールセットのtoggleSchemaに対応) / `updated_at`

### matches — 対局
`id` / `mode`(cpu, online_random, friend) / `room_id`(nullable) / `ruleset_key` / `rule_config`(jsonb, 開始時にrule_settings.configをスナップショットコピー、不変) / `game_type`(tonpuusen, hanchan) / `extension_count` / `end_reason` / `started_at` / `ended_at`

### match_players — 着席と結果
`match_id`(FK) / `seat` / `user_id`(nullable, null=CPU) / `cpu_difficulty` / `final_score` / `final_rank`（複合PK: match_id, seat）

### match_events — 着手イベント（リプレイの実体）
`match_id`(FK) / `seq_no` / `event_type`(draw, discard, call, riichi, tsumo, ron, kan, exhaustive_draw 等) / `payload`(jsonb) / `created_at`（複合PK: match_id, seq_no）

### replays — リプレイ公開設定
`match_id`(PK/FK) / `visibility`(private, friends, public) / `view_count` / `storage_url`(nullable)

## 主要な設計判断

- **ルールの不変性**: `rule_settings`はプリセット（編集され得る）、`matches.rule_config`はその開始時点のコピー。プリセットを直しても過去の対局のルール表示は変わらない
- **複数ルールセット対応**: `rule_settings`と`matches`は`ruleset_key`を持ち、どの`RulesetDefinition`実装を使う対局かを識別する（05参照）
- **リプレイ=イベント再生**: 盤面のスナップショットではなく`match_events`の逐次ログを保存。再生時はmahjong_engineでイベントを最初から適用し直して盤面を復元
- **段位はデータ駆動**: `dan_tiers`を参照テーブルにし、しきい値や段位数の変更をコード変更なしで運用できるようにする
- **再接続はDBに置かない**: 再接続トークンや進行中の盤面バッファはRedis（STEP2）が保持。Postgresは対局が確定した後の永続データのみを扱う

## 主な一意制約・インデックス

- `rooms.room_code`（unique）
- `friends(user_id, friend_id)`（unique）
- `match_events(match_id, seq_no)`（unique）
- `rating_history(user_id, created_at)`（推移グラフ用）
- `match_players(user_id, match_id)`（対局履歴一覧用）
