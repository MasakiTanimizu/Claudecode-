import { describe, it, expect } from 'vitest';
import {
  computeSpringChips,
  getActiveSeasons,
  computeAutumnBonusHan,
  applySummerRankUp,
} from '../scoring/SeasonEffects.js';

function t(suit, rank, variant = null) {
  return { suit, rank, variant };
}

describe('SeasonEffects', () => {
  it('spring chips equal the number of flowers held at extraction time', () => {
    expect(computeSpringChips(1)).toBe(1);
    expect(computeSpringChips(4)).toBe(4);
  });

  it('getActiveSeasons combines the winners own flowers with any flower shown as a dora/ura indicator', () => {
    const seasons = getActiveSeasons(
      [t('f', 1)], // winner extracted spring
      [t('f', 3)], // autumn showed as dora indicator
      [t('f', 4)], // winter showed as ura indicator
    );
    expect(seasons).toEqual(new Set([1, 3, 4]));
  });

  it('adds +1 han per 5-tile in the hand when autumn is active', () => {
    const hand = [t('p', 5, 'black'), t('s', 5, 'red'), t('p', 4)];
    const active = new Set([3]);
    expect(computeAutumnBonusHan(hand, active)).toBe(2); // p5 + s5, not p4

    const inactive = new Set([]);
    expect(computeAutumnBonusHan(hand, inactive)).toBe(0);
  });

  it('ranks a mangan+ hand up one tier when summer is active', () => {
    const active = new Set([2]);
    expect(applySummerRankUp(2000, active)).toBe(3000);
    expect(applySummerRankUp(3000, active)).toBe(4000);
    expect(applySummerRankUp(8000, active)).toBe(8000); // already top tier, stays capped
  });

  it('does not rank up when summer is inactive', () => {
    expect(applySummerRankUp(2000, new Set([]))).toBe(2000);
  });

  it('promotes a yakuman hand to 5x when summer is active', () => {
    const active = new Set([2]);
    expect(applySummerRankUp(8000, active, { isYakuman: true })).toBe(40000);
  });
});
