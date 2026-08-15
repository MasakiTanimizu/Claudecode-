import { describe, it, expect } from 'vitest';
import { rollDice } from '../chips/DiceEngine.js';

describe('DiceEngine.rollDice', () => {
  it('always returns a value between 1 and 6 (default 6-sided die)', () => {
    for (let i = 0; i < 200; i++) {
      const roll = rollDice();
      expect(roll).toBeGreaterThanOrEqual(1);
      expect(roll).toBeLessThanOrEqual(6);
      expect(Number.isInteger(roll)).toBe(true);
    }
  });

  it('supports a custom number of sides', () => {
    for (let i = 0; i < 100; i++) {
      const roll = rollDice(4);
      expect(roll).toBeGreaterThanOrEqual(1);
      expect(roll).toBeLessThanOrEqual(4);
    }
  });

  it('produces more than one distinct value across many rolls (sanity, not a strict uniformity test)', () => {
    const seen = new Set();
    for (let i = 0; i < 100; i++) seen.add(rollDice());
    expect(seen.size).toBeGreaterThan(1);
  });
});
