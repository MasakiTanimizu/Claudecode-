import { describe, it, expect } from 'vitest';
import { createRuleConfig } from '../../src/engine3p/rules/RuleConfig.js';
import { createPlayerState } from '../../src/engine3p/state/PlayerState.js';
import { createRoundState } from '../../src/engine3p/state/RoundState.js';
import { createScoreState, createChipState } from '../../src/engine3p/state/ScoreState.js';
import { createFlowerState } from '../../src/engine3p/state/FlowerState.js';
import { createWhitePotchiState } from '../../src/engine3p/state/WhitePotchiState.js';
import { createShubaState } from '../../src/engine3p/state/ShubaState.js';
import { GameLoop } from '../GameLoop.js';

function t(suit, rank, variant = null) {
  return { id: `${suit}${rank}-${Math.random()}`, suit, rank, variant };
}

function makeGame({ liveWall = [] } = {}) {
  const ruleConfig = createRuleConfig();
  const players = [0, 1, 2].map((seat) => createPlayerState(seat, { isDealer: seat === 0 }));
  const round = createRoundState({ dealerSeat: 0 });
  round.doraIndicators = [t('z', 6)];
  round.uraDoraIndicators = [t('z', 6)];
  return {
    ruleConfig,
    players,
    round,
    score: createScoreState(3, ruleConfig),
    chip: createChipState(3),
    wall: {
      liveWall,
      deadWall: {
        doraIndicators: [],
        uraDoraIndicators: [],
        kanDoraPool: [t('p', 4), t('p', 5), t('p', 6), t('p', 7)],
        kanUraDoraPool: [t('s', 4), t('s', 5), t('s', 6), t('s', 7)],
        replacementPool: [t('p', 9)],
      },
    },
    flower: createFlowerState(3),
    whitePotchi: createWhitePotchiState(3),
    shubariichi: createShubaState(3),
    alice: { active: false, chain: 0, revealedTiles: [] },
    ranking: { finished: false, order: [], rankPoints: [0, 0, 0] },
  };
}

// 234p 456p 678s 345s + one of a 2p pair (13 tiles); drawing/ronning the
// matching 2p completes a tanyao hand (same shape as TurnEngine.test.js).
function tanyaoWaitingTiles() {
  return [
    t('p', 2), t('p', 3), t('p', 4),
    t('p', 4), t('p', 5), t('p', 6),
    t('s', 6), t('s', 7), t('s', 8),
    t('s', 3), t('s', 4), t('s', 5),
    t('p', 2),
  ];
}

function collectEvents() {
  const events = [];
  return { events, onEvent: (e) => events.push(e) };
}

describe('GameLoop', () => {
  it('auto-plays full random hands (no human seat) to a handResult without throwing', () => {
    for (let i = 0; i < 15; i++) {
      const { events, onEvent } = collectEvents();
      const loop = new GameLoop({ humanSeat: -1, onEvent });
      loop.start();
      expect(events.length).toBeGreaterThan(0);
      expect(events[events.length - 1].type).toBe('handResult');
    }
  });

  it('resolves a human tsumo when the drawn tile completes the hand', () => {
    const winTile = t('p', 2);
    const game = makeGame({ liveWall: [winTile] });
    game.players[0].hand = tanyaoWaitingTiles();

    const { events, onEvent } = collectEvents();
    const loop = new GameLoop({ game, humanSeat: 0, onEvent });
    loop.start();

    expect(loop.phase).toBe('awaiting_human_action');
    loop.humanTsumo();

    const result = events[events.length - 1];
    expect(result.type).toBe('handResult');
    expect(result.isTsumo).toBe(true);
    expect(result.winner).toBe(0);
    expect(loop.phase).toBe('hand_over');
  });

  it('emits an error instead of resolving tsumo when the hand is not actually complete', () => {
    const game = makeGame({ liveWall: [t('m', 1)] });
    const { events, onEvent } = collectEvents();
    const loop = new GameLoop({ game, humanSeat: 0, onEvent });
    loop.start();

    loop.humanTsumo();
    expect(events[events.length - 1]).toEqual({ type: 'error', message: 'No tsumo available' });
    expect(loop.phase).toBe('awaiting_human_action');
  });

  it('resolves a CPU-only ron immediately after a human discard (no callOpportunity needed)', () => {
    const winTile = t('p', 2);
    const game = makeGame({ liveWall: [t('m', 1)] });
    game.players[0].hand = [...tanyaoWaitingTiles().slice(1), winTile]; // filler + the tile we'll discard
    game.players[1].hand = tanyaoWaitingTiles(); // tenpai, waits on the matching 2p

    const { events, onEvent } = collectEvents();
    const loop = new GameLoop({ game, humanSeat: 0, onEvent });
    loop.start();

    loop.humanDiscard(winTile.id);

    const result = events[events.length - 1];
    expect(result.type).toBe('handResult');
    expect(result.isTsumo).toBe(false);
    expect(result.winners).toEqual([1]);
    expect(result.discarderSeat).toBe(0);
  });

  it('offers a callOpportunity when the human can ron, and resolves on humanRon()', () => {
    const waitTile = t('p', 2);
    const game = makeGame({ liveWall: [t('m', 1)] });
    game.players[1].hand = tanyaoWaitingTiles(); // human, tenpai waiting on the matching 2p
    game.players[0].discards.push(waitTile); // simulate seat 0 (CPU/dealer) having just discarded it

    const { events, onEvent } = collectEvents();
    const loop = new GameLoop({ game, humanSeat: 1, onEvent });
    loop._afterDiscard(0);

    expect(loop.phase).toBe('awaiting_human_ron');
    const callEvent = events[events.length - 1];
    expect(callEvent).toMatchObject({ type: 'callOpportunity', fromSeat: 0, discardedTile: waitTile });

    loop.humanRon();
    const result = events[events.length - 1];
    expect(result.type).toBe('handResult');
    expect(result.winners).toEqual([1]);
  });

  it('still pays out a CPU ron on the same discard even when the human passes', () => {
    const waitTile = t('p', 2);
    const game = makeGame({ liveWall: [] });
    game.players[1].hand = tanyaoWaitingTiles(); // human, eligible
    game.players[2].hand = tanyaoWaitingTiles(); // CPU, also eligible (multi-ron)
    game.players[0].discards.push(waitTile);

    const { events, onEvent } = collectEvents();
    const loop = new GameLoop({ game, humanSeat: 1, onEvent });
    loop._afterDiscard(0);
    expect(loop.pendingRon.cpuSeats).toEqual([2]);

    loop.humanPass();
    const result = events[events.length - 1];
    expect(result.type).toBe('handResult');
    expect(result.winners).toEqual([2]);
  });

  it('resolves a double ron (human + CPU) together when the human accepts', () => {
    const waitTile = t('p', 2);
    const game = makeGame({ liveWall: [] });
    game.players[1].hand = tanyaoWaitingTiles();
    game.players[2].hand = tanyaoWaitingTiles();
    game.players[0].discards.push(waitTile);

    const { events, onEvent } = collectEvents();
    const loop = new GameLoop({ game, humanSeat: 1, onEvent });
    loop._afterDiscard(0);

    loop.humanRon();
    const result = events[events.length - 1];
    expect(result.type).toBe('handResult');
    expect(result.winners.sort()).toEqual([1, 2]);
  });

  it('rejects out-of-phase human actions with an error event instead of throwing', () => {
    const game = makeGame({ liveWall: [t('m', 1), t('m', 2)] });
    const { events, onEvent } = collectEvents();
    const loop = new GameLoop({ game, humanSeat: 0, onEvent });
    loop.start();

    expect(() => loop.humanRon()).not.toThrow();
    expect(events[events.length - 1]).toEqual({ type: 'error', message: 'No ron available' });
  });
});
