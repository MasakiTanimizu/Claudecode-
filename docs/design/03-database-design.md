# STEP3: DB設計

## テーブル一覧

### users — アカウント
`id` / `auth_provider`(google, apple, guest) / `external_id` / `display_name` / `avatar_url` / `is_guest` / `created_at`

### player_stats — 累積成績（難易度を問わない通算）
`user_id`(PK/FK) / `games_played` / `rank_sum` / `top_count` / `last_played_at`

段位・ELOレーティングは廃止（STEP3追補参照）。

### player_difficulty_stats — 難易度帯ごとの成績
`user_id`(FK) / `difficulty`(easy, medium, hard) / `games_played` / `chip_balance` / `rank_sum` / `top_count`（複合PK: user_id, difficulty）

「レート」は難易度に紐づく固定値（簡単=0.5・中=100・難=200）であり、プレイヤーが直接選ぶものではない。プレイヤーが選ぶのは難易度で、レートはそこから決まる祝儀の倍率。難易度帯ごとに収支・成績を分けて集計する。

### chip_settlements — 祝儀チップ増減ログ
`id` / `user_id`(FK) / `match_id`(FK) / `difficulty` / `chip_delta`（難易度に紐づくレートを掛けた後の実際の祝儀増減） / `final_rank` / `created_at`

### friends — フレンド関係
`user_id`(FK) / `friend_id`(FK) / `status`(pending, accepted, blocked) / `created_at`（複合PK: user_id, friend_id）

### rooms — 友人戦ルーム
`id` / `room_code`(unique, 6桁) / `host_user_id`(FK) / `rule_settings_id`(FK) / `ruleset_key` / `difficulty`(easy, medium, hard, 既定medium) / `status`(waiting, in_progress, finished) / `allow_spectate` / `created_at`

### room_members — 入室者
`room_id`(FK) / `user_id`(FK) / `seat` / `is_ready` / `is_spectator`（複合PK: room_id, user_id）

### rule_settings — ルールプリセット
`id` / `owner_user_id`(nullable, null=運営提供の既定プリセット) / `ruleset_key`（どの`RulesetDefinition`実装を使うか） / `name` / `config`(jsonb, そのルールセットのtoggleSchemaに対応) / `updated_at`

### matches — 対局
`id` / `mode`(cpu, online_random, friend) / `room_id`(nullable) / `ruleset_key` / `rule_config`(jsonb, 開始時にrule_settings.configをスナップショットコピー、不変) / `difficulty`(easy, medium, hard) / `game_type`(tonpuusen, hanchan; デフォルトtonpuusen) / `extension_count` / `end_reason`(normal, bust, aborted, maintenance) / `started_at` / `ended_at`

祝儀清算時のレート値(0.5/100/200)は`difficulty`から導出する（別列は持たない）。オンライン対戦でマッチング不成立によりCPUが空席を埋めた場合も`mode`は`online_random`のまま、該当`match_players.user_id`がnullになるだけで、この対局も通常通り記録・`player_difficulty_stats`に反映される。

### match_players — 着席と結果
`match_id`(FK) / `seat` / `user_id`(nullable, null=CPU) / `cpu_difficulty` / `final_score` / `final_rank` / `left_at_seq`(int, nullable — 再接続の猶予切れで恒久的にCPU代打ちへ切り替わった時点のmatch_events.seq_no。STEP9参照)（複合PK: match_id, seat）

### match_events — 着手イベント（リプレイの実体）
`match_id`(FK) / `seq_no` / `event_type`(draw, discard, call, riichi, tsumo, ron, kan, exhaustive_draw 等) / `payload`(jsonb) / `created_at`（複合PK: match_id, seq_no）

### replays — リプレイ公開設定
`match_id`(PK/FK) / `visibility`(private, friends, public) / `view_count` / `storage_url`(nullable)

## 主要な設計判断

- **ルールの不変性**: `rule_settings`はプリセット（編集され得る）、`matches.rule_config`はその開始時点のコピー。プリセットを直しても過去の対局のルール表示は変わらない
- **複数ルールセット対応**: `rule_settings`と`matches`は`ruleset_key`を持ち、どの`RulesetDefinition`実装を使う対局かを識別する（05参照）
- **リプレイ=イベント再生**: 盤面のスナップショットではなく`match_events`の逐次ログを保存。再生時はmahjong_engineでイベントを最初から適用し直して盤面を復元
- **段位は廃止、レートは難易度の従属値**: プレイヤーが選ぶのは難易度（簡単/中/難）のみ。レート（0.5/100/200）は難易度から機械的に決まる祝儀の倍率であり、独立した入力やELO的な推移スコアは持たない
- **再接続はDBに置かない**: 再接続トークンや進行中の盤面バッファはRedis（STEP2）が保持。Postgresは対局が確定した後の永続データのみを扱う

## 主な一意制約・インデックス

- `rooms.room_code`（unique）
- `friends(user_id, friend_id)`（unique）
- `match_events(match_id, seq_no)`（unique）
- `chip_settlements(user_id, created_at)`（収支推移グラフ用）
- `match_players(user_id, match_id)`（対局履歴一覧用）
