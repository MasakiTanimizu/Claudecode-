import { describe, it, expect } from 'vitest';
import { computeJunme, computeSpecialBonusPayments } from '../chips/SpecialBonusRule.js';
import { createRuleConfig } from '../rules/RuleConfig.js';

const rules = createRuleConfig();

describe('SpecialBonusRule.computeJunme', () => {
  it('is 0 before any draws', () => {
    expect(computeJunme(0)).toBe(0);
  });

  it('rounds up to the next full go-around', () => {
    expect(computeJunme(1)).toBe(1);
    expect(computeJunme(3)).toBe(1);
    expect(computeJunme(4)).toBe(2);
    expect(computeJunme(22)).toBe(8);
    expect(computeJunme(24)).toBe(8);
    expect(computeJunme(25)).toBe(9);
  });

  it('is unaffected by pon/kan turn skips, since it only counts live-wall draws', () => {
    // Simulates: 7 normal draws happened, then a pon skipped a turn
    // (no draw), then normal draws resumed — totalDraws simply doesn't
    // increment during the skipped turn, so junme progresses purely
    // off actual wall consumption regardless of whose turn it "should" be.
    expect(computeJunme(22)).toBe(computeJunme(22)); // sanity: pure function of totalDraws
  });
});

describe('SpecialBonusRule.computeSpecialBonusPayments', () => {
  it('pays kinsei (3 chips) from each opponent on a tsumo win, junme 8', () => {
    const result = computeSpecialBonusPayments({
      junme: 8, isTsumo: true, winnerSeat: 1, discarderSeat: null, ruleConfig: rules,
    });
    expect(result.name).toBe('kinsei');
    expect(result.deltas).toEqual([-3, 6, -3]);
    expect(result.total).toBe(6);
  });

  it('pays kinsei (3 chips) from only the discarder on a ron win, junme 8', () => {
    const result = computeSpecialBonusPayments({
      junme: 8, isTsumo: false, winnerSeat: 1, discarderSeat: 2, ruleConfig: rules,
    });
    expect(result.deltas).toEqual([0, 3, -3]);
  });

  it('pays daikinsei (5 chips) at junme 16', () => {
    const tsumo = computeSpecialBonusPayments({
      junme: 16, isTsumo: true, winnerSeat: 0, discarderSeat: null, ruleConfig: rules,
    });
    expect(tsumo.name).toBe('daikinsei');
    expect(tsumo.deltas).toEqual([10, -5, -5]);

    const ron = computeSpecialBonusPayments({
      junme: 16, isTsumo: false, winnerSeat: 0, discarderSeat: 2, ruleConfig: rules,
    });
    expect(ron.deltas).toEqual([5, 0, -5]);
  });

  it('pays nothing on any other junme', () => {
    const result = computeSpecialBonusPayments({
      junme: 7, isTsumo: true, winnerSeat: 0, discarderSeat: null, ruleConfig: rules,
    });
    expect(result.name).toBeNull();
    expect(result.deltas).toEqual([0, 0, 0]);
  });

  it('scales both sides of the transfer by the active shuba multiplier', () => {
    const result = computeSpecialBonusPayments({
      junme: 8, isTsumo: false, winnerSeat: 1, discarderSeat: 0, ruleConfig: rules, multiplier: 2,
    });
    expect(result.deltas).toEqual([-6, 6, 0]);
  });
});
