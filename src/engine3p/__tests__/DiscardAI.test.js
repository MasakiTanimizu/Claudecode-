import { describe, it, expect } from 'vitest';
import { chooseDiscard } from '../ai/DiscardAI.js';
import { DEFAULT_AI_WEIGHTS } from '../ai/AIWeights.js';

function t(id, suit, rank) {
  return { id, suit, rank, variant: null };
}

function baseCtx(overrides = {}) {
  return {
    hand: [],
    meldCount: 0,
    doraIndicators: [],
    uraDoraIndicators: [],
    riichiActive: false,
    kitaCount: 0,
    roundWind: 99, // no honor tile used in these hands matches this, avoids yakuhai noise
    seatWind: 98,
    isMenzen: true,
    opponentsDiscards: [],
    ...overrides,
  };
}

describe('DiscardAI.chooseDiscard', () => {
  it('discards an isolated tile rather than breaking a ryanmen partial', () => {
    const hand = [
      t('a', 'p', 1), t('b', 'p', 2), t('c', 'p', 3),
      t('d', 'p', 4), t('e', 'p', 5), t('f', 'p', 6),
      t('g', 's', 7), t('h', 's', 8), // ryanmen partial
      t('i', 'm', 1), t('j', 'm', 1), // pair
      t('k', 'z', 1), t('l', 'z', 2), t('m', 'z', 3),
      t('n', 's', 9),
    ];
    const result = chooseDiscard(baseCtx({ hand }), DEFAULT_AI_WEIGHTS);
    // Any of the 4 isolated tiles (z1, z2, z3, s9) is a valid answer;
    // discarding from the s7/s8 partial would be strictly worse.
    expect(['k', 'l', 'm', 'n']).toContain(result.tileId);
  });

  it('breaks the tie between equally useless tiles in favor of the genbutsu-safe one', () => {
    const hand = [
      t('a', 'p', 1), t('b', 'p', 2), t('c', 'p', 3),
      t('d', 'p', 4), t('e', 'p', 5), t('f', 'p', 6),
      t('g', 's', 7), t('h', 's', 8), t('i', 's', 9),
      t('j', 'm', 1), t('k', 'm', 1),
      t('l', 'z', 1), t('m', 'z', 2), // both isolated, symmetric otherwise
    ];
    const opponentsDiscards = [[{ suit: 'z', rank: 2 }]]; // z2 is genbutsu
    const result = chooseDiscard(baseCtx({ hand, opponentsDiscards }), DEFAULT_AI_WEIGHTS);
    expect(result.tileId).toBe('m'); // the z2 tile, id 'm'
  });

  it('throws on an empty hand', () => {
    expect(() => chooseDiscard(baseCtx({ hand: [] }), DEFAULT_AI_WEIGHTS)).toThrow();
  });
});
