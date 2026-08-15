import { describe, it, expect } from 'vitest';
import { runSelfPlayHand, rankRewards, evolveWeights } from '../ai/SelfPlay.js';
import { DEFAULT_AI_WEIGHTS } from '../ai/AIWeights.js';

describe('SelfPlay.runSelfPlayHand', () => {
  it('plays a full hand to either a tsumo win or an exhaustive draw without hanging', () => {
    const weightsBySeat = [DEFAULT_AI_WEIGHTS, DEFAULT_AI_WEIGHTS, DEFAULT_AI_WEIGHTS];
    const result = runSelfPlayHand(weightsBySeat);
    expect(result.finalScore.length).toBe(3);
    if (result.winner !== null) {
      expect([0, 1, 2]).toContain(result.winner);
      expect(result.result.han).toBeGreaterThan(0);
    } else {
      expect(result.exhaustive).toBe(true);
    }
  });
});

describe('SelfPlay.rankRewards', () => {
  it('gives +2/0/-2 for a clean 1st/2nd/3rd', () => {
    expect(rankRewards([35000, 40000, 25000])).toEqual([0, 2, -2]);
  });

  it('splits the reward for a tie', () => {
    // Two players tied at the top share the average of 1st and 2nd place reward.
    expect(rankRewards([40000, 40000, 20000])).toEqual([1, 1, -2]);
  });

  it('gives everyone the average reward on an all-tie', () => {
    expect(rankRewards([30000, 30000, 30000])).toEqual([0, 0, 0]);
  });
});

describe('SelfPlay.evolveWeights', () => {
  it('returns a candidate-or-baseline weight vector with the full key set intact', () => {
    const result = evolveWeights(DEFAULT_AI_WEIGHTS, { hands: 3, scale: 2 });
    expect(typeof result.accepted).toBe('boolean');
    expect(Object.keys(result.weights).sort()).toEqual(Object.keys(DEFAULT_AI_WEIGHTS).sort());
    expect(Number.isFinite(result.candidateAvg)).toBe(true);
    expect(Number.isFinite(result.baseAvg)).toBe(true);
  });

  it('never mutates the caller-provided baseline weights object', () => {
    const baseline = { ...DEFAULT_AI_WEIGHTS };
    evolveWeights(baseline, { hands: 2, scale: 1 });
    expect(baseline).toEqual(DEFAULT_AI_WEIGHTS);
  });
});
