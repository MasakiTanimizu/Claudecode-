# STEP4: 通信設計

通信は「RPC（クライアント→サーバー、応答あり）」と「Stream（サーバー→クライアント、一方向配信）」の2種類のみ。

## ランダムマッチ成立フロー

1. `matchmaking.enqueue(ruleSettingsId, difficulty)`をRPC呼び出し（`difficulty`は easy/medium/hard。STEP7の「対戦」で選ぶ唯一の入力で、レートはこれに紐づく固定値）
2. サーバーがRedisの待機キューに登録（同一ルール設定・同一difficultyのプレイヤー同士でグルーピング）
3. 3人揃った時点でroom・matchを作成し、`rule_settings.config`を`rule_config`へスナップショットコピー
4. 各クライアントへ`MatchFound(matchId, seat, opponents)`をStream配信
5. 各クライアントが対局用Streamを購読し、初回`MatchStateSnapshot`を受信して対局画面へ遷移
6. **7秒以内に3人揃わなければ**、クライアントが`matchmaking.cancel`を呼び、空席をCPUで埋めた対局を`mode: online_random`のまま開始する（STEP7 FIG.10参照）。この対局も通常通り記録・`player_difficulty_stats`に反映される

## 友人戦フロー

1. ホストが`rooms.create(ruleSettingsId)`を呼び、6桁の`room_code`を受け取る
2. 参加者は`rooms.join(room_code)`で入室（観戦希望は`isSpectator=true`）
3. 入退室のたびに`RoomMemberJoined / RoomMemberLeft`をStream配信
4. 全員`rooms.setReady()`後、ホストが`rooms.start()`でmatchを生成
5. 以降はランダムマッチと同じ対局Streamに合流（観戦者は読み取り専用購読者）

## 切断〜再接続シーケンス

1. クライアント切断検知 → サーバーがRedisに切断フラグ＋猶予タイマー(60秒)を設定
2. 他プレイヤーへ`PlayerDisconnected(seat)`を配信
3. 猶予期間中、本人のターンが来たら設定「途中CPU代打ち」がONの場合は自動着手（他家には通常のTurnUpdateとして配信）
4. クライアントが`session.resume(reconnectToken)`を呼ぶ
5. サーバーがトークンを検証し、`MatchStateSnapshot`（マスク済み最新盤面）を一括送信
6. 他プレイヤーへ`PlayerReconnected(seat)`を配信、通常のRPC/Streamに復帰
7. 猶予タイマー切れの場合は、対局終了までCPU代打ちを継続。再接続は成立せず、結果はルール設定に従って確定

## メッセージカタログ

**RPC**: `matchmaking.enqueue/cancel` / `rooms.create/join/leave/setReady/start` / `match.discard/call/riichi/openRiichi/tsumo/ron/pass` / `session.resume/heartbeat`

**Stream**: `MatchFound/MatchStarting` / `RoomMemberJoined/Left` / `MatchStateSnapshot` / `TurnUpdate` / `DoraRevealed` / `AgariResult` / `ExhaustiveDraw` / `PlayerDisconnected/Reconnected` / `MatchEnded`

## 設計判断の要点

- **盤面マスキング**: `TurnUpdate`/`MatchStateSnapshot`は受信者ごとに生成する個別ペイロード。他家の非公開牌は枚数のみの裏面プレースホルダーに置き換える
- **サーバー権威**: すべての`match.*`呼び出しはサーバー側でmahjong_engineにより再検証する。クライアント側の合法手チェックはUXのための先読みに過ぎない
- **手番タイマー**: 打牌は既定20秒・鳴き/ロン判断は既定5秒（設定で変更可）。タイムアウト時は自動ツモ切り／自動パス
- **観戦**: 常に3席分すべてをマスクした`TurnUpdate`を配信。対局ロジックは変更せず配信対象を増やすだけで実現
- **冪等性**: RPCに`requestId`を付与し、再接続直後の操作の二重適用を防ぐ
