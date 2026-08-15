import { describe, it, expect } from 'vitest';
import { computeChips } from '../chips/ChipEngine.js';
import { createRuleConfig } from '../rules/RuleConfig.js';

const rules = createRuleConfig();

function tile(suit, rank, variant = null) {
  return { suit, rank, variant };
}

describe('ChipEngine.computeChips', () => {
  it('awards 3 chips per red tile in the winning hand', () => {
    const result = computeChips({
      handTiles: [tile('p', 5, 'red'), tile('s', 5, 'red'), tile('p', 2)],
      isMenzen: true,
      riichiActive: false,
    }, rules);
    expect(result.subtotal).toBe(6);
    expect(result.breakdown.find((b) => b.name === 'red').count).toBe(2);
  });

  it('awards 1 chip for ippatsu', () => {
    const result = computeChips({ handTiles: [], ippatsu: true }, rules);
    expect(result.total).toBe(1);
  });

  it('awards 1 chip per kita tile the winner drew', () => {
    const result = computeChips({ handTiles: [], kitaCount: 3 }, rules);
    expect(result.total).toBe(3);
  });

  it('counts uradora chips only for a menzen riichi hand', () => {
    const hand = [tile('p', 4), tile('p', 4)];
    const indicators = [tile('p', 3)];
    const withRiichi = computeChips({
      handTiles: hand, isMenzen: true, riichiActive: true, uraDoraIndicators: indicators,
    }, rules);
    expect(withRiichi.total).toBe(2);

    const withoutRiichi = computeChips({
      handTiles: hand, isMenzen: true, riichiActive: false, uraDoraIndicators: indicators,
    }, rules);
    expect(withoutRiichi.total).toBe(0);
  });

  it('combines multiple chip sources before applying the shuba multiplier', () => {
    const result = computeChips({
      handTiles: [tile('p', 5, 'red')],
      ippatsu: true,
      kitaCount: 1,
      isWin: true,
      shubaTier: 'shuba',
    }, rules);
    // red(3) + ippatsu(1) + kita(1) = 5, then x2 for shuba
    expect(result.subtotal).toBe(5);
    expect(result.multiplier).toBe(2);
    expect(result.total).toBe(10);
  });

  it('applies the shubante x10 multiplier', () => {
    const result = computeChips({
      handTiles: [],
      ippatsu: true,
      isWin: true,
      shubaTier: 'shubante',
    }, rules);
    expect(result.total).toBe(10);
  });

  it('does not apply a shuba multiplier on a non-win evaluation', () => {
    const result = computeChips({
      handTiles: [],
      ippatsu: true,
      isWin: false,
      shubaTier: 'shubante',
    }, rules);
    expect(result.multiplier).toBe(1);
    expect(result.total).toBe(1);
  });

  it('nets out already-paid hana chips so a non-shuba win owes nothing extra for them', () => {
    const result = computeChips({
      handTiles: [],
      ippatsu: true,
      isWin: true,
      shubaTier: null,
      hanaChips: 3,
    }, rules);
    // ippatsu(1) + hana(3) = 4 subtotal, x1 multiplier, minus the 3 already paid = 1.
    expect(result.subtotal).toBe(4);
    expect(result.alreadyPaid).toBe(3);
    expect(result.total).toBe(1);
  });

  it('tops hana chips up to the multiplied amount on a shuba win', () => {
    const result = computeChips({
      handTiles: [],
      isWin: true,
      shubaTier: 'shuba', // x2
      hanaChips: 3,
    }, rules);
    // Owed in total: 3 * 2 = 6. Already paid: 3. Additional owed now: 3.
    expect(result.total).toBe(3);
  });

  it('tops hana chips up fully on a shubante win (x10)', () => {
    const result = computeChips({
      handTiles: [],
      isWin: true,
      shubaTier: 'shubante',
      hanaChips: 2,
    }, rules);
    // Owed in total: 2 * 10 = 20. Already paid: 2. Additional owed now: 18.
    expect(result.total).toBe(18);
  });
});
