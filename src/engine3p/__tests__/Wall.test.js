import { describe, it, expect } from 'vitest';
import { createRuleConfig } from '../rules/RuleConfig.js';
import {
  createWall, dealHands, drawTile, drawReplacement, remainingDraws, isExhausted,
  revealKanDora, revealKanUraDora, peekNextAliceTile,
} from '../wall/Wall.js';

function deterministicShuffle(tiles) {
  // identity shuffle for reproducible tests
  return tiles.slice();
}

describe('Wall', () => {
  const rules = createRuleConfig();

  it('keeps all 112 tiles across live wall + dead wall', () => {
    const wall = createWall(rules);
    const total = wall.liveWall.length
      + wall.deadWall.doraIndicators.length
      + wall.deadWall.uraDoraIndicators.length
      + wall.deadWall.kanDoraPool.length
      + wall.deadWall.kanUraDoraPool.length
      + wall.deadWall.replacementPool.length;
    expect(total).toBe(112);
  });

  it('reveals exactly RULE_DORA_DISPLAY_COUNT dora and ura indicators', () => {
    const wall = createWall(rules);
    expect(wall.deadWall.doraIndicators.length).toBe(2);
    expect(wall.deadWall.uraDoraIndicators.length).toBe(2);
  });

  it('deals 13 tiles to each of 3 players and reduces the live wall', () => {
    const wall = createWall(rules, { shuffle: deterministicShuffle });
    const liveBefore = wall.liveWall.length;
    const hands = dealHands(wall, 3, 13);
    expect(hands.length).toBe(3);
    hands.forEach((h) => expect(h.length).toBe(13));
    expect(wall.liveWall.length).toBe(liveBefore - 39);
  });

  it('drawTile removes one tile from the live wall front', () => {
    const wall = createWall(rules, { shuffle: deterministicShuffle });
    const before = wall.liveWall[0];
    const drawn = drawTile(wall);
    expect(drawn).toBe(before);
  });

  it('drawReplacement keeps the dead wall size constant and shrinks the live wall by 1', () => {
    const wall = createWall(rules, { shuffle: deterministicShuffle });
    const liveBefore = wall.liveWall.length;
    const poolSizeBefore = wall.deadWall.replacementPool.length;
    drawReplacement(wall);
    expect(wall.liveWall.length).toBe(liveBefore - 1);
    expect(wall.deadWall.replacementPool.length).toBe(poolSizeBefore);
  });

  it('supports repeated replacement draws until the live wall is exhausted', () => {
    const wall = createWall(rules, { shuffle: deterministicShuffle });
    let draws = 0;
    while (!isExhausted(wall) && draws < 500) {
      drawReplacement(wall);
      draws++;
    }
    expect(remainingDraws(wall)).toBe(0);
    expect(drawReplacement(wall)).toBeNull();
  });

  it('reserves RULE_MAX_KAN_DORA kan-dora and matching kan-uradora slots', () => {
    const wall = createWall(rules);
    expect(wall.deadWall.kanDoraPool.length).toBe(4);
    expect(wall.deadWall.kanUraDoraPool.length).toBe(4);
  });

  it('revealKanDora/revealKanUraDora pop one tile each, in order, until exhausted', () => {
    const wall = createWall(rules, { shuffle: deterministicShuffle });
    const firstKanDora = wall.deadWall.kanDoraPool[0];
    const firstKanUraDora = wall.deadWall.kanUraDoraPool[0];

    expect(revealKanDora(wall)).toBe(firstKanDora);
    expect(revealKanUraDora(wall)).toBe(firstKanUraDora);
    expect(wall.deadWall.kanDoraPool.length).toBe(3);
    expect(wall.deadWall.kanUraDoraPool.length).toBe(3);

    for (let i = 0; i < 3; i++) revealKanDora(wall);
    expect(wall.deadWall.kanDoraPool.length).toBe(0);
    expect(revealKanDora(wall)).toBeNull(); // 5th kan: no more reserved kan-dora
  });

  it('peekNextAliceTile points at the next unused kan-dora slot', () => {
    const wall = createWall(rules, { shuffle: deterministicShuffle });
    expect(peekNextAliceTile(wall)).toBe(wall.deadWall.kanDoraPool[0]);
    revealKanDora(wall);
    expect(peekNextAliceTile(wall)).toBe(wall.deadWall.kanDoraPool[0]);
  });

  it('falls back to the replacement pool for peekNextAliceTile once kan-dora is exhausted', () => {
    const wall = createWall(rules, { shuffle: deterministicShuffle });
    for (let i = 0; i < 4; i++) revealKanDora(wall);
    expect(wall.deadWall.kanDoraPool.length).toBe(0);
    expect(peekNextAliceTile(wall)).toBe(wall.deadWall.replacementPool[0]);
  });
});
