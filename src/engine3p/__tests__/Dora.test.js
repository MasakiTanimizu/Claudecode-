import { describe, it, expect } from 'vitest';
import { doraSuccessor, countDoraMatches } from '../tiles/Dora.js';

function t(suit, rank) {
  return { suit, rank };
}

describe('Dora', () => {
  it('cycles pin/sou ranks 1-9 with wraparound', () => {
    expect(doraSuccessor(t('p', 3))).toEqual({ suit: 'p', rank: 4 });
    expect(doraSuccessor(t('s', 9))).toEqual({ suit: 's', rank: 1 });
  });

  it('treats man 1 and 9 as each others successor (only 2 ranks exist)', () => {
    expect(doraSuccessor(t('m', 1))).toEqual({ suit: 'm', rank: 9 });
    expect(doraSuccessor(t('m', 9))).toEqual({ suit: 'm', rank: 1 });
  });

  it('cycles winds East->South->West->North->East', () => {
    expect(doraSuccessor(t('z', 1))).toEqual({ suit: 'z', rank: 2 });
    expect(doraSuccessor(t('z', 4))).toEqual({ suit: 'z', rank: 1 });
  });

  it('cycles dragons Haku->Hatsu->Chun->Haku', () => {
    expect(doraSuccessor(t('z', 5))).toEqual({ suit: 'z', rank: 6 });
    expect(doraSuccessor(t('z', 7))).toEqual({ suit: 'z', rank: 5 });
  });

  it('counts how many hand tiles match the dora for each indicator', () => {
    const hand = [t('p', 4), t('p', 4), t('s', 1), t('m', 9)];
    const indicators = [t('p', 3), t('m', 1)];
    expect(countDoraMatches(hand, indicators)).toBe(3); // two p4 + one m9
  });
});
