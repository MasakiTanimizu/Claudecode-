import { describe, it, expect } from 'vitest';
import { createGameState } from '../state/GameState.js';

describe('GameState', () => {
  it('deals 3 players 13 tiles each with correct starting score', () => {
    const game = createGameState();
    expect(game.players.length).toBe(3);
    game.players.forEach((p) => expect(p.hand.length).toBe(13));
    expect(game.score).toEqual([35000, 35000, 35000]);
  });

  it('reveals 2 dora indicators on the round state', () => {
    const game = createGameState();
    expect(game.round.doraIndicators.length).toBe(2);
    expect(game.round.uraDoraIndicators.length).toBe(2);
  });

  it('seat 0 starts as dealer', () => {
    const game = createGameState();
    expect(game.players[0].isDealer).toBe(true);
    expect(game.round.dealerSeat).toBe(0);
  });

  it('accepts ruleConfig overrides', () => {
    const game = createGameState({ ruleConfig: { RULE_STARTING_SCORE: 25000 } });
    expect(game.score).toEqual([25000, 25000, 25000]);
  });
});
