// WebSocket server wrapping GameLoop, per docs/UNITY_INTEGRATION.md's
// protocol. Each connection gets its own independent local game (1
// human seat + 2 CPU seats) — there is no room/matchmaking layer yet
// (see docs/UNITY_INTEGRATION.md's 未実装・今後の課題 section).

import { WebSocketServer } from 'ws';
import { GameLoop } from './GameLoop.js';

const PORT = Number(process.env.PORT) || 8080;

function send(ws, payload) {
  if (ws.readyState !== ws.OPEN) return;
  ws.send(JSON.stringify(payload));
}

function handleMessage(ws, loop, msg) {
  switch (msg.type) {
    case 'discard':
      return loop.humanDiscard(msg.tileId);
    case 'riichi':
      return loop.humanRiichi({ open: msg.open ?? false, shubaTier: msg.shubaTier ?? null });
    case 'kita':
      return loop.humanKita(msg.tileId);
    case 'hana':
      return loop.humanHana(msg.tileId);
    case 'tsumo':
      return loop.humanTsumo();
    case 'ron':
      return loop.humanRon();
    case 'pass':
      return loop.humanPass();
    default:
      return send(ws, { type: 'error', message: `Unknown message type: ${msg.type}` });
  }
}

export function createServer({ port = PORT } = {}) {
  const wss = new WebSocketServer({ port });

  wss.on('connection', (ws) => {
    let loop = null;

    ws.on('message', (raw) => {
      let msg;
      try {
        msg = JSON.parse(raw);
      } catch {
        return send(ws, { type: 'error', message: 'Malformed JSON message' });
      }

      if (msg.type === 'join') {
        loop = new GameLoop({ onEvent: (event) => send(ws, event) });
        loop.start();
        return;
      }

      if (!loop) return send(ws, { type: 'error', message: 'Send a join message first' });
      handleMessage(ws, loop, msg);
    });
  });

  // eslint-disable-next-line no-console
  console.log(`Mahjong WebSocket server listening on ws://localhost:${port}`);
  return wss;
}

if (import.meta.url === `file://${process.argv[1]}`) {
  createServer();
}
