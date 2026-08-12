import { describe, it, expect } from 'vitest';
import { resolveCallPriority } from '../engine/CallPriority.js';

describe('CallPriority.resolveCallPriority', () => {
  it('ron always outranks pon and kan', () => {
    const result = resolveCallPriority(0, [
      { seat: 1, type: 'pon' },
      { seat: 2, type: 'ron' },
    ]);
    expect(result.type).toBe('ron');
    expect(result.winners).toEqual([2]);
  });

  it('honors multiple simultaneous ron claims (multi-ron, no head-bump rule)', () => {
    const result = resolveCallPriority(0, [
      { seat: 1, type: 'ron' },
      { seat: 2, type: 'ron' },
    ]);
    expect(result.type).toBe('ron');
    expect(result.winners.sort()).toEqual([1, 2]);
    expect(result.contested).toBe(true);
  });

  it('gives pon and kan equal priority — a lone claim of either wins', () => {
    const ponResult = resolveCallPriority(0, [{ seat: 1, type: 'pon' }]);
    expect(ponResult).toEqual({ type: 'pon', winners: [1], contested: false });

    const kanResult = resolveCallPriority(0, [{ seat: 2, type: 'kan' }]);
    expect(kanResult).toEqual({ type: 'kan', winners: [2], contested: false });
  });

  it('breaks a pon-vs-kan tie by seating proximity to the discarder, not call type', () => {
    // Discarder is seat 0. Seat 1 acts right after them (distance 1),
    // seat 2 is farther (distance 2). Seat 1's kan should win over seat
    // 2's pon purely on proximity, since pon/kan are equal priority.
    const result = resolveCallPriority(0, [
      { seat: 2, type: 'pon' },
      { seat: 1, type: 'kan' },
    ]);
    expect(result.type).toBe('kan');
    expect(result.winners).toEqual([1]);
    expect(result.contested).toBe(true);
  });

  it('returns no winner when nobody claims the discard', () => {
    expect(resolveCallPriority(0, [])).toEqual({ type: null, winners: [] });
  });

  it('never lets the discarder claim their own discard', () => {
    const result = resolveCallPriority(0, [{ seat: 0, type: 'pon' }]);
    expect(result).toEqual({ type: null, winners: [] });
  });
});
