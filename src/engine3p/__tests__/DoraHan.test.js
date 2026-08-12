import { describe, it, expect } from 'vitest';
import { computeDoraHan } from '../scoring/DoraHan.js';

function t(suit, rank, variant = null) {
  return { suit, rank, variant };
}

describe('DoraHan.computeDoraHan', () => {
  it('counts regular dora matches from the dora indicators', () => {
    const result = computeDoraHan({
      handTiles: [t('p', 4), t('p', 4)],
      doraIndicators: [t('p', 3)],
      uraDoraIndicators: [],
      riichiActive: false,
      kitaCount: 0,
    });
    expect(result.normalDora).toBe(2);
    expect(result.total).toBe(2);
  });

  it('always counts red tiles as aka-dora regardless of riichi', () => {
    const result = computeDoraHan({
      handTiles: [t('p', 5, 'red')],
      doraIndicators: [],
      uraDoraIndicators: [],
      riichiActive: false,
      kitaCount: 0,
    });
    expect(result.akaDora).toBe(1);
    expect(result.total).toBe(1);
  });

  it('only counts uradora and blue tiles when riichi is active', () => {
    const handTiles = [t('p', 4), t('s', 5, 'blue')];
    const withoutRiichi = computeDoraHan({
      handTiles, doraIndicators: [], uraDoraIndicators: [t('p', 3)], riichiActive: false, kitaCount: 0,
    });
    expect(withoutRiichi.uraDora).toBe(0);

    const withRiichi = computeDoraHan({
      handTiles, doraIndicators: [], uraDoraIndicators: [t('p', 3)], riichiActive: true, kitaCount: 0,
    });
    // 1 uradora match (p4) + 1 blue-tile-as-uradora (s5) = 2
    expect(withRiichi.uraDora).toBe(2);
  });

  it('adds nuki-dora han equal to the extracted kita count', () => {
    const result = computeDoraHan({
      handTiles: [], doraIndicators: [], uraDoraIndicators: [], riichiActive: false, kitaCount: 3,
    });
    expect(result.nukiDora).toBe(3);
    expect(result.total).toBe(3);
  });

  it('sums every dora source together', () => {
    const result = computeDoraHan({
      handTiles: [t('p', 4), t('p', 5, 'red'), t('s', 5, 'blue')],
      doraIndicators: [t('p', 3)],
      uraDoraIndicators: [],
      riichiActive: true,
      kitaCount: 2,
    });
    // normal: p4 matches p3->p4 = 1; aka: red p5 = 1; ura: blue s5 = 1; nuki: 2
    expect(result.total).toBe(5);
  });
});
