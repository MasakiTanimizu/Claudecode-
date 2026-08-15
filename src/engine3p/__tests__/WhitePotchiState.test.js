import { describe, it, expect } from 'vitest';
import { createWhitePotchiState, markHakuPotchiIfDrawn } from '../state/WhitePotchiState.js';

function potchi() {
  return { suit: 'z', rank: 5, variant: 'potchi' };
}

function plainHaku() {
  return { suit: 'z', rank: 5, variant: 'black' };
}

describe('WhitePotchiState', () => {
  it('starts with nothing revealed or active', () => {
    const state = createWhitePotchiState(3);
    expect(state.revealedBySeat).toEqual([false, false, false]);
    expect(state.activeBySeat).toEqual([false, false, false]);
  });

  it('ignores a non-potchi haku tile', () => {
    const state = createWhitePotchiState(3);
    const next = markHakuPotchiIfDrawn(state, 0, plainHaku(), { riichiActive: false, riichiEverDeclared: false });
    expect(next).toBe(state);
  });

  it('marks revealed but not active when drawn without riichi', () => {
    const state = createWhitePotchiState(3);
    const next = markHakuPotchiIfDrawn(state, 1, potchi(), { riichiActive: false, riichiEverDeclared: false });
    expect(next.revealedBySeat[1]).toBe(true);
    expect(next.activeBySeat[1]).toBe(false);
  });

  it('marks active permanently when drawn during riichi', () => {
    const state = createWhitePotchiState(3);
    const next = markHakuPotchiIfDrawn(state, 2, potchi(), { riichiActive: true, riichiEverDeclared: true });
    expect(next.activeBySeat[2]).toBe(true);
  });

  it('marks immediate (即白ポッチ) only when riichi has never been declared this hand', () => {
    const state = createWhitePotchiState(3);
    const beforeRiichi = markHakuPotchiIfDrawn(state, 0, potchi(), { riichiActive: false, riichiEverDeclared: false });
    expect(beforeRiichi.immediateBySeat[0]).toBe(true);

    const afterRiichi = markHakuPotchiIfDrawn(state, 0, potchi(), { riichiActive: true, riichiEverDeclared: true });
    expect(afterRiichi.immediateBySeat[0]).toBe(false);
  });
});
