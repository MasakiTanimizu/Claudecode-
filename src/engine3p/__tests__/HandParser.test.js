import { describe, it, expect } from 'vitest';
import {
  decomposeStandardHand,
  isChiitoitsu,
  isKokushi,
  isComplete,
} from '../hand/HandParser.js';

function t(suit, rank) {
  return { suit, rank };
}

function many(suit, rank, n) {
  return Array.from({ length: n }, () => t(suit, rank));
}

describe('HandParser', () => {
  it('decomposes a standard 4-set + pair hand using pin/sou sequences and a triplet', () => {
    const tiles = [
      t('p', 1), t('p', 2), t('p', 3),
      t('p', 4), t('p', 5), t('p', 6),
      t('p', 7), t('p', 8), t('p', 9),
      t('s', 1), t('s', 2), t('s', 3),
      t('p', 5), t('p', 5),
    ];
    const results = decomposeStandardHand(tiles);
    expect(results.length).toBeGreaterThan(0);
    expect(results.some((d) => d.melds.length === 4 && d.pair)).toBe(true);
  });

  it('never forms a sequence in the man suit even if hypothetical consecutive ranks are present', () => {
    // Contrived: not a legal 3p hand (man only has 1/9), but proves the
    // sequence search structurally excludes 'm' regardless of ranks.
    const tiles = [t('m', 1), t('m', 2), t('m', 3), ...many('p', 1, 2), ...many('s', 1, 2), t('z', 5), t('z', 5)];
    const results = decomposeStandardHand(tiles);
    const anyManSequence = results.some((d) => d.melds.some((m) => m.type === 'sequence' && m.suit === 'm'));
    expect(anyManSequence).toBe(false);
  });

  it('recognizes chiitoitsu (7 distinct pairs)', () => {
    const tiles = [
      ...many('m', 1, 2), ...many('m', 9, 2),
      ...many('p', 2, 2), ...many('p', 8, 2),
      ...many('s', 3, 2), ...many('s', 7, 2),
      ...many('z', 5, 2),
    ];
    expect(isChiitoitsu(tiles)).toBe(true);
    expect(isComplete(tiles, 0)).toBe(true);
  });

  it('rejects chiitoitsu when a tile appears 4 times', () => {
    const tiles = [
      ...many('m', 1, 4),
      ...many('p', 2, 2), ...many('p', 8, 2),
      ...many('s', 3, 2), ...many('s', 7, 2),
      ...many('z', 5, 2),
    ];
    expect(isChiitoitsu(tiles)).toBe(false);
  });

  it('recognizes kokushi musou (13 terminals/honors + 1 duplicate)', () => {
    const tiles = [
      t('m', 1), t('m', 1), t('m', 9), t('p', 1), t('p', 9),
      t('s', 1), t('s', 9), t('z', 1), t('z', 2), t('z', 3),
      t('z', 4), t('z', 5), t('z', 6), t('z', 7),
    ];
    expect(isKokushi(tiles)).toBe(true);
  });

  it('supports melded (furo) hands where the concealed part only needs the remaining sets', () => {
    // 1 meld already called (pon of z5) -> concealed part needs 3 sets + pair.
    const concealed = [
      t('p', 1), t('p', 2), t('p', 3),
      t('p', 4), t('p', 5), t('p', 6),
      t('s', 7), t('s', 8), t('s', 9),
      t('m', 1), t('m', 1),
    ];
    expect(isComplete(concealed, 1)).toBe(true);
  });

  it('rejects an incomplete hand', () => {
    const tiles = [
      t('p', 1), t('p', 2), t('p', 4),
      t('p', 4), t('p', 5), t('p', 6),
      t('s', 7), t('s', 8), t('s', 9),
      t('m', 1), t('m', 1), t('m', 9), t('m', 9), t('z', 1),
    ];
    expect(isComplete(tiles, 0)).toBe(false);
  });
});
