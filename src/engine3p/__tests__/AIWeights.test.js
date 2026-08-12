import { describe, it, expect } from 'vitest';
import { DEFAULT_AI_WEIGHTS, cloneWeights, perturbWeights } from '../ai/AIWeights.js';

describe('AIWeights', () => {
  it('clones without sharing references', () => {
    const clone = cloneWeights(DEFAULT_AI_WEIGHTS);
    clone.shanten = 999;
    expect(DEFAULT_AI_WEIGHTS.shanten).not.toBe(999);
  });

  it('perturbs every key, including currently-zero forward-looking hooks', () => {
    const rng = () => 1; // always jitter fully positive
    const next = perturbWeights(DEFAULT_AI_WEIGHTS, { scale: 2, rng });
    expect(next.yakumanPotential).toBeGreaterThan(0);
    expect(next.aliceExpectation).toBeGreaterThan(0);
    expect(next.shanten).toBeGreaterThan(DEFAULT_AI_WEIGHTS.shanten);
  });

  it('never perturbs a weight below 0', () => {
    const rng = () => 0; // always jitter fully negative
    const next = perturbWeights({ x: 0.5 }, { scale: 10, rng });
    expect(next.x).toBe(0);
  });
});
