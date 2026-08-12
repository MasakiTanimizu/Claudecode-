import { describe, it, expect } from 'vitest';
import { createRuleConfig } from '../rules/RuleConfig.js';
import { createPlayerState } from '../state/PlayerState.js';
import { createRoundState } from '../state/RoundState.js';
import { createScoreState, createChipState } from '../state/ScoreState.js';
import {
  drawForTurn,
  discardTile,
  declareKita,
  checkTsumoWin,
  checkRonWin,
  resolveWin,
  resolveExhaustiveDraw,
  canDeclareChi,
  refreshFuriten,
} from '../engine/TurnEngine.js';

function t(suit, rank, variant = null) {
  return { id: `${suit}${rank}-${Math.random()}`, suit, rank, variant };
}

function makeGame({ liveWall = [] } = {}) {
  const ruleConfig = createRuleConfig();
  const players = [0, 1, 2].map((seat) => createPlayerState(seat, { isDealer: seat === 0, score: 35000 }));
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
      deadWall: { doraIndicators: [], uraDoraIndicators: [], replacementPool: [t('p', 9)] },
    },
    flower: { drawnBySeat: [[], [], []] },
    shubariichi: { tier: [null, null, null] },
  };
}

// Tanyao tsumo hand: 234p 456p 678s 345s 22p pair.
function tanyaoTiles() {
  return [
    t('p', 2), t('p', 3), t('p', 4),
    t('p', 4), t('p', 5), t('p', 6),
    t('s', 6), t('s', 7), t('s', 8),
    t('s', 3), t('s', 4), t('s', 5),
    t('p', 2), t('p', 2),
  ];
}

describe('TurnEngine', () => {
  it('detects and resolves a menzen tsumo win, paying the winner from both opponents', () => {
    const game = makeGame();
    game.players[1].hand = tanyaoTiles();

    const win = checkTsumoWin(game, 1);
    expect(win.canWin).toBe(true);
    expect(win.yakuResult.yakuList.map((y) => y.name)).toEqual(expect.arrayContaining(['タンヤオ', '門前自摸']));

    const before = [...game.score];
    resolveWin(game, win);
    expect(game.score[1]).toBeGreaterThan(before[1]);
    expect(game.score[0]).toBeLessThan(before[0]);
    expect(game.score[2]).toBeLessThan(before[2]);
  });

  it('detects and resolves a ron win, paying only the discarder', () => {
    const game = makeGame();
    const hand13 = tanyaoTiles().slice(0, 13);
    game.players[1].hand = hand13;
    const winTile = tanyaoTiles()[13];

    const win = checkRonWin(game, 1, 2, winTile);
    expect(win.canWin).toBe(true);

    const before = [...game.score];
    resolveWin(game, win);
    expect(game.score[1]).toBeGreaterThan(before[1]);
    expect(game.score[2]).toBeLessThan(before[2]);
    expect(game.score[0]).toBe(before[0]);
  });

  it('marks a player furiten when a winning tile is in their own discards, blocking ron', () => {
    const game = makeGame();
    const hand13 = tanyaoTiles().slice(0, 13);
    game.players[1].hand = hand13;
    game.players[1].discards.push(tanyaoTiles()[13]);
    refreshFuriten(game, 1);

    expect(game.players[1].furiten).toBe(true);
    const win = checkRonWin(game, 1, 2, tanyaoTiles()[13]);
    expect(win.canWin).toBe(false);
    expect(win.reason).toBe('furiten');
  });

  it('extracts a north tile into kitaTiles and draws a replacement', () => {
    const game = makeGame({ liveWall: [t('s', 1)] });
    const north = t('z', 4);
    game.players[0].hand = [north];

    const { extracted, replacement } = declareKita(game, 0, north.id);
    expect(extracted.suit).toBe('z');
    expect(extracted.rank).toBe(4);
    expect(game.players[0].kitaTiles.length).toBe(1);
    expect(replacement).toBeTruthy();
    expect(game.players[0].hand).toContain(replacement);
  });

  it('draws from the live wall on a normal turn', () => {
    const tile = t('p', 1);
    const game = makeGame({ liveWall: [tile] });
    const drawn = drawForTurn(game, 2);
    expect(drawn).toBe(tile);
    expect(game.players[2].hand).toContain(tile);
    expect(game.wall.liveWall.length).toBe(0);
  });

  it('discards a tile out of a players hand', () => {
    const tile = t('p', 1);
    const game = makeGame();
    game.players[0].hand = [tile];
    const discarded = discardTile(game, 0, tile.id);
    expect(discarded).toBe(tile);
    expect(game.players[0].hand.length).toBe(0);
    expect(game.players[0].discards).toContain(tile);
  });

  it('pays noten players into tenpai players at an exhaustive draw', () => {
    const game = makeGame();
    // seat 0 tenpai (needs one p2/p5/p8 to complete a simple pinfu-ish shape... use a clean 13-tile tenpai hand)
    game.players[0].hand = tanyaoTiles().slice(0, 13);
    game.players[1].hand = [t('z', 1), t('z', 2), t('z', 3), t('m', 1), t('m', 9), t('p', 1), t('s', 1)];
    game.players[2].hand = [t('z', 1), t('z', 2), t('z', 3), t('m', 1), t('m', 9), t('p', 1), t('s', 1)];

    const before = [...game.score];
    const { tenpaiFlags } = resolveExhaustiveDraw(game);
    expect(tenpaiFlags[0]).toBe(true);
    expect(game.score[0]).toBeGreaterThan(before[0]);
    expect(game.score[1]).toBeLessThan(before[1]);
  });

  it('never allows chi on man/honor/flower tiles, only pin/sou', () => {
    expect(canDeclareChi(null, null, { suit: 'm', rank: 1 })).toBe(false);
    expect(canDeclareChi(null, null, { suit: 'z', rank: 5 })).toBe(false);
    expect(canDeclareChi(null, null, { suit: 'f', rank: 1 })).toBe(false);
    expect(canDeclareChi(null, null, { suit: 'p', rank: 4 })).toBe(true);
  });
});
