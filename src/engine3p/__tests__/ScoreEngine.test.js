import { describe, it, expect } from 'vitest';
import {
  computeFu,
  computeBasePoints,
  computeWinPayments,
  applyHonba,
  resolveNotenPayments,
} from '../scoring/ScoreEngine.js';
import { createRuleConfig } from '../rules/RuleConfig.js';

const rules = createRuleConfig();

describe('ScoreEngine.computeFu', () => {
  it('gives pinfu tsumo a flat 20 fu', () => {
    expect(computeFu({ melds: [], pair: null }, [], { hasPinfu: true, isTsumo: true })).toBe(20);
  });

  it('gives pinfu ron a flat 30 fu', () => {
    expect(computeFu({ melds: [], pair: null }, [], { hasPinfu: true, isTsumo: false })).toBe(30);
  });

  it('gives chiitoitsu a flat 25 fu regardless of shape', () => {
    expect(computeFu({ melds: [], pair: null }, [], { isChiitoitsu: true, isTsumo: true })).toBe(25);
  });

  it('adds concealed triplet + menzen-ron fu and rounds up to the nearest 10', () => {
    const decomposition = { melds: [{ type: 'triplet', suit: 'z', rank: 5 }], pair: { suit: 'p', rank: 2 } };
    const fu = computeFu(decomposition, [], {
      isTsumo: false, isMenzen: true, winTile: { suit: 's', rank: 1 }, waitIsTwoSided: false,
    });
    // 20 base + 8 (concealed honor triplet) + 10 (menzen ron) + 2 (non-ryanmen wait) = 40
    expect(fu).toBe(40);
  });

  it('treats a ron-completed triplet as open (half fu) even though the hand stays menzen', () => {
    const decomposition = { melds: [{ type: 'triplet', suit: 'z', rank: 5 }], pair: { suit: 'p', rank: 2 } };
    const fu = computeFu(decomposition, [], {
      isTsumo: false, isMenzen: true, winTile: { suit: 'z', rank: 5 }, waitIsTwoSided: true,
    });
    // 20 base + 4 (ron-completed honor triplet counts as open) + 10 (menzen ron) + 0 (ryanmen) = 34 -> 40
    expect(fu).toBe(40);
  });
});

describe('ScoreEngine.computeBasePoints', () => {
  it('uses the standard fu * 2^(2+han) formula below mangan', () => {
    expect(computeBasePoints(30, 3)).toBe(960);
  });

  it('caps at 2000 (mangan) once the formula would exceed it', () => {
    expect(computeBasePoints(40, 4)).toBe(2000);
  });

  it('uses the fixed mangan-and-up table for han >= 5', () => {
    expect(computeBasePoints(30, 5)).toBe(2000);
    expect(computeBasePoints(30, 6)).toBe(3000);
    expect(computeBasePoints(30, 8)).toBe(4000);
    expect(computeBasePoints(30, 11)).toBe(6000);
    expect(computeBasePoints(30, 13)).toBe(8000);
  });
});

describe('ScoreEngine.computeWinPayments', () => {
  it('computes a non-dealer ron: total from the single discarder', () => {
    const { deltas, total } = computeWinPayments({
      fu: 30, han: 3, isDealer: false, isTsumo: false, winnerSeat: 1, discarderSeat: 0,
    });
    expect(total).toBe(3900);
    expect(deltas).toEqual([-3900, 3900, 0]);
  });

  it('computes a dealer ron with the 6x multiplier', () => {
    const { deltas, total } = computeWinPayments({
      fu: 30, han: 3, isDealer: true, isTsumo: false, winnerSeat: 0, discarderSeat: 2,
    });
    expect(total).toBe(5800);
    expect(deltas).toEqual([5800, 0, -5800]);
  });

  it('splits a non-dealer tsumo 2:1 between the dealer and the other player', () => {
    const { deltas, total } = computeWinPayments({
      fu: 30, han: 3, isDealer: false, isTsumo: true, winnerSeat: 1, dealerSeat: 0,
    });
    expect(total).toBe(3900);
    expect(deltas).toEqual([-2600, 3900, -1300]);
  });

  it('splits a dealer tsumo evenly ("all")', () => {
    const { deltas, total } = computeWinPayments({
      fu: 30, han: 3, isDealer: true, isTsumo: true, winnerSeat: 0, dealerSeat: 0,
    });
    expect(total).toBe(5800);
    expect(deltas).toEqual([5800, -2900, -2900]);
  });

  it('never nets the winner less via tsumo than the equivalent ron total ("ツモ損なし")', () => {
    const { total } = computeWinPayments({
      fu: 40, han: 1, isDealer: false, isTsumo: true, winnerSeat: 1, dealerSeat: 0,
    });
    const ronTotal = computeWinPayments({
      fu: 40, han: 1, isDealer: false, isTsumo: false, winnerSeat: 1, discarderSeat: 0,
    }).total;
    expect(total).toBeGreaterThanOrEqual(ronTotal);
  });

  describe('mangan-and-up fixed table (base >= 2000)', () => {
    it('pays a non-dealer (child) yakuman ron 32000, matching the real 3-player table', () => {
      const { deltas, total } = computeWinPayments({
        forcedBase: 8000, isDealer: false, isTsumo: false, winnerSeat: 1, discarderSeat: 2,
      });
      expect(total).toBe(32000);
      expect(deltas).toEqual([0, 32000, -32000]);
    });

    it('splits a non-dealer (child) yakuman tsumo as 12000 (other) / 20000 (dealer)', () => {
      const { deltas, total } = computeWinPayments({
        forcedBase: 8000, isDealer: false, isTsumo: true, winnerSeat: 1, dealerSeat: 0,
      });
      expect(total).toBe(32000);
      expect(deltas).toEqual([-20000, 32000, -12000]);
    });

    it('pays a dealer yakuman ron 48000', () => {
      const { deltas, total } = computeWinPayments({
        forcedBase: 8000, isDealer: true, isTsumo: false, winnerSeat: 0, discarderSeat: 2,
      });
      expect(total).toBe(48000);
      expect(deltas).toEqual([48000, 0, -48000]);
    });

    it('splits a dealer yakuman tsumo evenly as 24000 all', () => {
      const { deltas, total } = computeWinPayments({
        forcedBase: 8000, isDealer: true, isTsumo: true, winnerSeat: 0, dealerSeat: 0,
      });
      expect(total).toBe(48000);
      expect(deltas).toEqual([48000, -24000, -24000]);
    });

    it('scales linearly for other mangan+ tiers (mangan, haneman, baiman, sanbaiman)', () => {
      const child_ron = (base) => computeWinPayments({ forcedBase: base, isDealer: false, isTsumo: false, winnerSeat: 1, discarderSeat: 0 }).total;
      expect(child_ron(2000)).toBe(8000); // mangan
      expect(child_ron(3000)).toBe(12000); // haneman
      expect(child_ron(4000)).toBe(16000); // baiman
      expect(child_ron(6000)).toBe(24000); // sanbaiman
    });

    it('scales up further for the summer-boosted 5-baiman tier (base 40000, multiplier 20)', () => {
      const { total } = computeWinPayments({
        forcedBase: 40000, isDealer: false, isTsumo: false, winnerSeat: 1, discarderSeat: 0,
      });
      expect(total).toBe(160000); // 8000 (child ron unit) * (40000/2000)
    });
  });
});

describe('ScoreEngine.applyHonba', () => {
  it('adds a flat amount from the discarder on ron', () => {
    const deltas = applyHonba([0, 0, 0], {
      honba: 1, isTsumo: false, winnerSeat: 1, discarderSeat: 0, ruleConfig: rules,
    });
    expect(deltas).toEqual([-2000, 2000, 0]);
  });

  it('adds RULE_HONBA_TSUMO from each opponent on tsumo', () => {
    const deltas = applyHonba([0, 0, 0], {
      honba: 1, isTsumo: true, winnerSeat: 0, ruleConfig: rules,
    });
    expect(deltas).toEqual([2000, -1000, -1000]);
  });

  it('scales with the honba count', () => {
    const deltas = applyHonba([0, 0, 0], {
      honba: 3, isTsumo: false, winnerSeat: 1, discarderSeat: 0, ruleConfig: rules,
    });
    expect(deltas).toEqual([-6000, 6000, 0]);
  });
});

describe('ScoreEngine.resolveNotenPayments', () => {
  it('pays the pool from 2 noten players to 1 tenpai player', () => {
    expect(resolveNotenPayments([true, false, false], rules)).toEqual([2000, -1000, -1000]);
  });

  it('pays the pool from 1 noten player to 2 tenpai players', () => {
    expect(resolveNotenPayments([true, true, false], rules)).toEqual([1000, 1000, -2000]);
  });

  it('exchanges nothing when everyone is tenpai', () => {
    expect(resolveNotenPayments([true, true, true], rules)).toEqual([0, 0, 0]);
  });

  it('exchanges nothing when nobody is tenpai', () => {
    expect(resolveNotenPayments([false, false, false], rules)).toEqual([0, 0, 0]);
  });
});
