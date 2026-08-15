import { describe, it, expect } from 'vitest';
import { distributeZeroSumChips } from '../chips/ChipPayment.js';

describe('ChipPayment.distributeZeroSumChips', () => {
  it('collects the full amount from each opponent on a tsumo win', () => {
    const result = distributeZeroSumChips(4, { isTsumo: true, winnerSeat: 0, discarderSeat: null });
    expect(result.deltas).toEqual([8, -4, -4]);
    expect(result.total).toBe(8);
  });

  it('collects the full amount from only the discarder on a ron win', () => {
    const result = distributeZeroSumChips(4, { isTsumo: false, winnerSeat: 0, discarderSeat: 2 });
    expect(result.deltas).toEqual([4, 0, -4]);
    expect(result.total).toBe(4);
  });

  it('is a no-op for a zero amount', () => {
    const result = distributeZeroSumChips(0, { isTsumo: true, winnerSeat: 1, discarderSeat: null });
    expect(result.deltas).toEqual([0, 0, 0]);
    expect(result.total).toBe(0);
  });
});
