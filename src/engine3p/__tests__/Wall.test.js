import { describe, it, expect } from 'vitest';
import { createRuleConfig } from '../rules/RuleConfig.js';
import { createWall, dealHands, drawTile, drawReplacement, remainingDraws, isExhausted } from '../wall/Wall.js';

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
});
