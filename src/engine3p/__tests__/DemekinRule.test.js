import { describe, it, expect } from 'vitest';
import { isDemekinTriggered, computeDemekinPayment } from '../chips/DemekinRule.js';

describe('DemekinRule.isDemekinTriggered', () => {
  it('triggers on a pure (structural) yakuman', () => {
    expect(isDemekinTriggered({ isPureYakuman: true, fourFlowers: false, fourKita: false, isImmediateHakuPotchi: false })).toBe(true);
  });

  it('triggers on holding all 4 flowers', () => {
    expect(isDemekinTriggered({ isPureYakuman: false, fourFlowers: true, fourKita: false, isImmediateHakuPotchi: false })).toBe(true);
  });

  it('triggers on holding all 4 kita', () => {
    expect(isDemekinTriggered({ isPureYakuman: false, fourFlowers: false, fourKita: true, isImmediateHakuPotchi: false })).toBe(true);
  });

  it('triggers on immediate haku-potchi', () => {
    expect(isDemekinTriggered({ isPureYakuman: false, fourFlowers: false, fourKita: false, isImmediateHakuPotchi: true })).toBe(true);
  });

  it('does not trigger when none of the conditions hold', () => {
    expect(isDemekinTriggered({ isPureYakuman: false, fourFlowers: false, fourKita: false, isImmediateHakuPotchi: false })).toBe(false);
  });
});

describe('DemekinRule.computeDemekinPayment', () => {
  it('pays the dice value from each opponent on a tsumo win', () => {
    const result = computeDemekinPayment({ diceValue: 2, isTsumo: true, winnerSeat: 1, discarderSeat: null });
    expect(result.deltas).toEqual([-2, 4, -2]);
  });

  it('pays the dice value from only the discarder on a ron win', () => {
    const result = computeDemekinPayment({ diceValue: 5, isTsumo: false, winnerSeat: 1, discarderSeat: 0 });
    expect(result.deltas).toEqual([-5, 5, 0]);
  });

  it('scales the payment by the active shuba multiplier', () => {
    const result = computeDemekinPayment({ diceValue: 3, isTsumo: false, winnerSeat: 1, discarderSeat: 2, multiplier: 2 });
    expect(result.deltas).toEqual([0, 6, -6]);
  });
});
