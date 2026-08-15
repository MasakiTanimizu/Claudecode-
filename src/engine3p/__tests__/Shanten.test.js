import { describe, it, expect } from 'vitest';
import { shanten, standardShanten, chiitoiShanten, kokushiShanten } from '../ai/Shanten.js';
import { isTenpai, isComplete } from '../hand/HandParser.js';

function t(suit, rank) {
  return { suit, rank };
}

function many(suit, rank, n) {
  return Array.from({ length: n }, () => t(suit, rank));
}

describe('Shanten.standardShanten', () => {
  it('is -1 fewer than tenpai for a hand one tile away from complete (tenpai = 0)', () => {
    // 123p 456p 789p 123s + single p5 (tanki wait) = tenpai.
    const hand = [
      t('p', 1), t('p', 2), t('p', 3),
      t('p', 4), t('p', 5), t('p', 6),
      t('p', 7), t('p', 8), t('p', 9),
      t('s', 1), t('s', 2), t('s', 3),
      t('z', 5),
    ];
    expect(standardShanten(hand)).toBe(0);
  });

  it('increases as the hand gets further from complete', () => {
    const iishanten = [
      t('p', 1), t('p', 2), t('p', 3),
      t('p', 4), t('p', 5), t('p', 6),
      t('p', 7), t('p', 8),
      t('s', 1), t('s', 2), t('s', 3),
      t('z', 5), t('z', 6),
    ];
    expect(standardShanten(iishanten)).toBe(1);
  });

  it('accounts for already-called melds when computing shanten', () => {
    // 1 meld already called; concealed part needs 3 sets + pair.
    // 123p 456p 789s + single m1 (tanki wait) = tenpai with meldCount=1.
    const concealed = [
      t('p', 1), t('p', 2), t('p', 3),
      t('p', 4), t('p', 5), t('p', 6),
      t('s', 7), t('s', 8), t('s', 9),
      t('m', 1),
    ];
    expect(standardShanten(concealed, 1)).toBe(0);
  });

  it('agrees with HandParser.isTenpai on whether shanten is exactly 0', () => {
    const cases = [
      [
        t('p', 1), t('p', 2), t('p', 3),
        t('p', 4), t('p', 5), t('p', 6),
        t('p', 7), t('p', 8), t('p', 9),
        t('s', 1), t('s', 2), t('s', 3),
        t('z', 5),
      ],
      [
        t('z', 1), t('z', 2), t('z', 3),
        t('m', 1), t('m', 9), t('p', 1), t('s', 1),
      ],
    ];
    for (const hand of cases) {
      expect(standardShanten(hand) === 0).toBe(isTenpai(hand, 0));
    }
  });

  it('is -1 or lower is never expected from standardShanten on a 13-tile hand (use isComplete for wins)', () => {
    // Sanity: a 13-tile tenpai hand should never itself be "complete".
    const hand = [
      t('p', 1), t('p', 2), t('p', 3),
      t('p', 4), t('p', 5), t('p', 6),
      t('p', 7), t('p', 8), t('p', 9),
      t('s', 1), t('s', 2), t('s', 3),
      t('z', 5),
    ];
    expect(isComplete(hand, 0)).toBe(false);
    expect(standardShanten(hand)).toBeGreaterThanOrEqual(0);
  });
});

describe('Shanten.chiitoiShanten', () => {
  it('is 0 (tenpai) for 6 pairs + 1 unpaired tile', () => {
    const hand = [
      ...many('m', 1, 2), ...many('m', 9, 2),
      ...many('p', 2, 2), ...many('p', 8, 2),
      ...many('s', 3, 2), ...many('s', 7, 2),
      t('z', 5),
    ];
    expect(chiitoiShanten(hand)).toBe(0);
  });

  it('penalizes having fewer than 7 distinct tile kinds', () => {
    // 6 pairs of the same 2 kinds repeated doesn't help beyond 7 kinds.
    const fewKinds = [...many('m', 1, 2), ...many('m', 9, 2), ...many('p', 2, 2), t('p', 3), t('p', 4), t('p', 5), t('p', 6), t('p', 7)];
    expect(chiitoiShanten(fewKinds)).toBeGreaterThan(0);
  });
});

describe('Shanten.kokushiShanten', () => {
  it('is 0 (tenpai) for 12 unique terminals/honors + 1 duplicate', () => {
    const hand = [
      t('m', 1), t('m', 1), t('m', 9), t('p', 1), t('p', 9),
      t('s', 1), t('s', 9), t('z', 1), t('z', 2), t('z', 3),
      t('z', 4), t('z', 5), t('z', 6),
    ];
    expect(kokushiShanten(hand)).toBe(0);
  });

  it('is high for a hand with no terminals/honors at all', () => {
    const hand = [t('p', 4), t('p', 5), t('p', 6), t('s', 4), t('s', 5), t('s', 6)];
    expect(kokushiShanten(hand)).toBeGreaterThan(5);
  });
});

describe('Shanten.shanten (combined)', () => {
  it('takes the minimum across standard/chiitoi/kokushi', () => {
    const chiitoiTenpai = [
      ...many('m', 1, 2), ...many('m', 9, 2),
      ...many('p', 2, 2), ...many('p', 8, 2),
      ...many('s', 3, 2), ...many('s', 7, 2),
      t('z', 5),
    ];
    expect(shanten(chiitoiTenpai, 0)).toBe(0);
  });

  it('excludes chiitoi/kokushi once any meld has been called', () => {
    const concealed = [
      t('p', 1), t('p', 2), t('p', 3),
      t('p', 4), t('p', 5), t('p', 6),
      t('s', 7), t('s', 8), t('s', 9),
      t('m', 1),
    ];
    expect(shanten(concealed, 1)).toBe(standardShanten(concealed, 1));
  });
});
