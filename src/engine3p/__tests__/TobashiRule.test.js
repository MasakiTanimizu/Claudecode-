import { describe, it, expect } from 'vitest';
import { computeTobashiPayments } from '../chips/TobashiRule.js';
import { createRuleConfig } from '../rules/RuleConfig.js';

const rules = createRuleConfig();

describe('TobashiRule.computeTobashiPayments', () => {
  it('pays 10 chips to the winner when an opponent drops below zero', () => {
    const result = computeTobashiPayments({
      scoresBefore: [35000, 2000, 35000],
      scoresAfter: [45000, -1000, 25000],
      winnerSeat: 0,
      ruleConfig: rules,
    });
    expect(result.bustedSeats).toEqual([1]);
    expect(result.deltas).toEqual([10, -10, 0]);
  });

  it('treats a landing score of exactly 0 as busted too', () => {
    const result = computeTobashiPayments({
      scoresBefore: [35000, 2000, 35000],
      scoresAfter: [45000, 0, 25000],
      winnerSeat: 0,
      ruleConfig: rules,
    });
    expect(result.bustedSeats).toEqual([1]);
  });

  it('does not trigger for a player who stays above zero', () => {
    const result = computeTobashiPayments({
      scoresBefore: [35000, 5000, 35000],
      scoresAfter: [45000, 1000, 25000],
      winnerSeat: 0,
      ruleConfig: rules,
    });
    expect(result.bustedSeats).toEqual([]);
    expect(result.deltas).toEqual([0, 0, 0]);
  });

  it('does not re-charge a player who was already busted before this win', () => {
    const result = computeTobashiPayments({
      scoresBefore: [35000, -500, 35000],
      scoresAfter: [45000, -5500, 25000],
      winnerSeat: 0,
      ruleConfig: rules,
    });
    expect(result.bustedSeats).toEqual([]);
  });

  it('pays 10 chips from each opponent independently when a single tsumo busts both', () => {
    const result = computeTobashiPayments({
      scoresBefore: [10000, 1000, 500],
      scoresAfter: [30000, -2000, -3000],
      winnerSeat: 0,
      ruleConfig: rules,
    });
    expect(result.bustedSeats.sort()).toEqual([1, 2]);
    expect(result.deltas).toEqual([20, -10, -10]);
  });

  it('scales the per-bust amount by the active shuba multiplier', () => {
    const result = computeTobashiPayments({
      scoresBefore: [35000, 2000, 35000],
      scoresAfter: [45000, -1000, 25000],
      winnerSeat: 0,
      ruleConfig: rules,
      multiplier: 2,
    });
    expect(result.deltas).toEqual([20, -20, 0]);
  });
});
