import { describe, it, expect, afterEach } from 'vitest';
import WebSocket from 'ws';
import { createServer } from '../index.js';

let wss;

afterEach(() => {
  wss?.close();
  wss = undefined;
});

// Queues every frame as it arrives (rather than attaching a fresh
// `once('message', ...)` per await) so back-to-back synchronous sends
// from the server — e.g. GameLoop.start()'s pre-draw state immediately
// followed by the post-draw state — can't race past a not-yet-attached
// listener and get dropped.
function messageQueue(ws) {
  const queue = [];
  const waiters = [];
  ws.on('message', (raw) => {
    const msg = JSON.parse(raw);
    const waiter = waiters.shift();
    if (waiter) waiter(msg);
    else queue.push(msg);
  });
  return () => {
    if (queue.length > 0) return Promise.resolve(queue.shift());
    return new Promise((resolve) => waiters.push(resolve));
  };
}

function waitForOpen(ws) {
  return new Promise((resolve, reject) => {
    ws.once('open', resolve);
    ws.once('error', reject);
  });
}

describe('WebSocket server', () => {
  it('starts a game on join and streams a state frame back', async () => {
    wss = createServer({ port: 0 });
    const { port } = wss.address();
    const ws = new WebSocket(`ws://localhost:${port}`);
    await waitForOpen(ws);

    const nextMessage = messageQueue(ws);
    ws.send(JSON.stringify({ type: 'join', playerName: 'tester' }));
    const initial = await nextMessage(); // pre-draw, 13-tile hand
    expect(initial.type).toBe('state');
    expect(initial.state.players[0].hand.length).toBe(13);

    const afterDraw = await nextMessage(); // dealer's first draw, awaiting discard
    expect(afterDraw.type).toBe('state');
    expect(afterDraw.state.yourSeat).toBe(0);
    expect(Array.isArray(afterDraw.state.players)).toBe(true);
    expect(afterDraw.state.players[0].hand.length).toBe(14);

    ws.close();
  });

  it('rejects actions sent before a join message', async () => {
    wss = createServer({ port: 0 });
    const { port } = wss.address();
    const ws = new WebSocket(`ws://localhost:${port}`);
    await waitForOpen(ws);

    const nextMessage = messageQueue(ws);
    ws.send(JSON.stringify({ type: 'discard', tileId: 'whatever' }));
    const msg = await nextMessage();

    expect(msg).toEqual({ type: 'error', message: 'Send a join message first' });
    ws.close();
  });

  it('responds with an error frame for malformed JSON', async () => {
    wss = createServer({ port: 0 });
    const { port } = wss.address();
    const ws = new WebSocket(`ws://localhost:${port}`);
    await waitForOpen(ws);

    const nextMessage = messageQueue(ws);
    ws.send('not json');
    const msg = await nextMessage();

    expect(msg).toEqual({ type: 'error', message: 'Malformed JSON message' });
    ws.close();
  });
});
