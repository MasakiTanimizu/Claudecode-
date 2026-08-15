# Unity 連携ガイド（ローカルCPU対戦・WebSocketプロトコル）

## 方針

仕様書 section 52-55（サーバー権威型・牌山はサーバー生成・観戦者への
不正な情報漏洩防止）に合わせ、既存のルールエンジン（`src/engine3p/`）
は Node.js サーバー側で動かし、Unity はネットワーク越しにアクション
を送り、サーバーが返す状態を描画するだけの「薄いクライアント」とする。

今回のスコープは**ローカル1人対CPU2人**（`server/GameLoop.js`）。
サーバーは最初から localhost 前提ではなくネットワーク層
（WebSocket）を介して作っているため、将来オンライン対戦へ拡張する際
もサーバーコード自体は変更不要で、デプロイ先を変えるだけでよい。

この環境には Unity Editor がインストールされていないため、Unity側の
C#スクリプト（`unity-client/`）はこちらでは実行・検証できていません。
文法的に正しい形で提供していますが、実際にUnityプロジェクトに組み込んで
ビルド確認するのはユーザー側の作業になります。サーバー側（`server/`）は
Node.js上で動くJSなので、vitestで実際にWebSocket接続を張ってテスト済み
です（`server/__tests__/`）。

## 構成（実装済み）

```
server/
  GameLoop.js   # 1人対CPU2人のハンドロジック（TurnEngine + ai/DiscardAI を使用）
  index.js      # WebSocketサーバー本体（`ws` パッケージ使用）
  __tests__/
    GameLoop.test.js  # GameLoopの単体テスト（決定論的な盤面を直接注入）
    index.test.js     # 実際にWebSocket接続してjoin/state/errorを検証
unity-client/
  MahjongWebSocketClient.cs   # WebSocket接続 + メッセージ送受信（未検証、後述）
  MahjongMessages.cs          # JSONメッセージのモデルクラス（未検証、後述）
  MahjongClientExample.cs     # 使用例（接続して打牌するだけの最小サンプル、未検証、後述）
```

## 起動方法

```bash
npm install          # ws パッケージ済み（package.jsonのdependenciesに追加済み）
npm run server        # = node server/index.js
# ws://localhost:8080 で待受
```

## プロトコル

全メッセージはJSON、改行区切りではなく1メッセージ=1WebSocketフレーム。

### Client → Server

| type | フィールド | 説明 |
|---|---|---|
| `join` | `playerName` | 接続直後に送る。ゲームが新規作成され、人間は席0（東家）に着席、席1・2はCPU |
| `discard` | `tileId` | 自分の手牌からその牌を切る |
| `riichi` | `open?`, `shubaTier?`（`'shuba'\|'shubazoma'\|'shubante'\|null`） | リーチ宣言（次のdiscardと同時ではなく、宣言→discardの2段階） |
| `kita` | `tileId` | 北抜き |
| `hana` | `tileId` | 華抜き |
| `tsumo` | – | 自分のツモ番でツモ和了を宣言 |
| `ron` | – | ロン機会が提示されている間に和了を宣言 |
| `pass` | – | 提示されたロン/鳴き機会を見送る |

### Server → Client

| type | フィールド | 説明 |
|---|---|---|
| `state` | `state: GameStateView` | 状態が変化するたびに送信（後述のDTO） |
| `callOpportunity` | `discardedTile`, `fromSeat`, `options` | 人間にロン等の選択を促す（現状ロンのみ実装、鳴きはサーバー側CPUのみ対応） |
| `handResult` | 下記参照 | 局の結果 |
| `error` | `message` | 不正なアクションなど |

`handResult` は3パターン(ツモ・ロン/ダブロン・流局)で形が異なる。
`results` は和了した席ごとに1件、`TurnEngine.resolveWin` の戻り値
(`fu`, `han`, `base`, `yakuList`, `scoreDeltas`, `chipResult`,
`specialBonus`, `demekin`, `tobashi`, `doraResult`, `isYakuman` など)
をそのまま含む。

```jsonc
// ツモ
{ "type": "handResult", "winner": 0, "isTsumo": true,
  "results": [ { "seat": 0, "fu": 30, "han": 3, "base": 3900, "isYakuman": false,
                 "yakuList": [{"name":"タンヤオ","han":1}], "scoreDeltas": [3900,-1950,-1950], "...": "..." } ] }

// ロン(ダブロン可、winners.length === 2 のこともある)
{ "type": "handResult", "winners": [1], "isTsumo": false, "discarderSeat": 0,
  "results": [ { "seat": 1, "fu": 30, "han": 2, "base": 2000, "...": "..." } ] }

// 流局
{ "type": "handResult", "isDraw": true, "tenpaiFlags": [true, false, true], "deltas": [1500, -3000, 1500] }
```

### `GameStateView`（自分視点、他家の手牌は枚数のみ）

```jsonc
{
  "yourSeat": 0,
  "round": { "roundWind": 1, "roundNumber": 1, "honba": 0, "kyoutakuPoints": 0,
             "dealerSeat": 0, "turn": 0, "doraIndicators": [{"suit":"p","rank":3}] },
  "players": [
    { "seat": 0, "isDealer": true, "hand": [{"id":"p1-3","suit":"p","rank":1,"variant":null}, ...],
      "discards": [...], "melds": [...], "kitaCount": 0, "flowerCount": 0,
      "riichiActive": false, "score": 35000, "chip": 0 },
    { "seat": 1, "isDealer": false, "handSize": 13, "discards": [...], "melds": [...],
      "kitaCount": 0, "flowerCount": 0, "riichiActive": false, "score": 35000, "chip": 0 }
  ]
}
```

自分（`seat === yourSeat`）だけ `hand`（実際の牌配列）を持ち、他家は
`handSize`（枚数のみ）。観戦者向けの拡張も同じ原則で行う想定。

## CPUの簡易挙動（GameLoop.js）

- ツモ・ロンは可能なら必ず和了する（見逃しの判断はしない）
- 北・華牌は引いた瞬間に必ず抜く（国士無双含みで温存する、といった判断はしない）
- 門前かつテンパイに達したら必ず立直する（常に通常立直。シュバ系はCPUは選ばない）
- ポン・カンは判断・宣言そのものが未実装（後述）

## 未実装・今後の課題

- CPUの鳴き判断（ポン・カン）は未実装。人間へのロン提示のみ対応
- 人間側のポン・カン宣言メッセージは未実装（`declarePon`/`declareDaiminkan`/
  `declareAnkan`/`declareShouminkan` は既にエンジン側にあるので接続は容易）
- 複数ルーム・複数人間プレイヤー（友人戦・オンライン対戦）は未対応
- 観戦者向けの情報制限は未実装
- 半荘/東風戦としての局の連続進行（`nextRound`呼び出し・ゲーム終了判定）は
  未接続。現状は1局限りで `handResult` を返した後、GameLoopインスタンスは
  再利用されない
- Unity側のWebGLビルド対応（`System.Net.WebSockets.ClientWebSocket` は
  WebGLで動作しないため、WebGL版は `NativeWebSocket` 等の別パッケージが
  別途必要）
