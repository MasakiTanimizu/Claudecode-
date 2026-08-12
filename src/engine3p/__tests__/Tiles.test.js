import { describe, it, expect } from 'vitest';
import { createTileSet, countBySuit } from '../tiles/Tiles.js';
import { createRuleConfig } from '../rules/RuleConfig.js';

describe('Tiles', () => {
  const rules = createRuleConfig();
  const tiles = createTileSet(rules);

  it('produces exactly 112 tiles', () => {
    expect(tiles.length).toBe(112);
  });

  it('has the correct per-suit breakdown', () => {
    const counts = countBySuit(tiles);
    expect(counts.m).toBe(8);
    expect(counts.p).toBe(36);
    expect(counts.s).toBe(36);
    expect(counts.z).toBe(28);
    expect(counts.f).toBe(4);
  });

  it('only contains man tiles of rank 1 or 9', () => {
    const manRanks = new Set(tiles.filter((t) => t.suit === 'm').map((t) => t.rank));
    expect(manRanks).toEqual(new Set([1, 9]));
  });

  it('has 4 north tiles and 4 flower tiles total', () => {
    const north = tiles.filter((t) => t.suit === 'z' && t.rank === 4);
    const flowers = tiles.filter((t) => t.suit === 'f');
    expect(north.length).toBe(4);
    expect(flowers.length).toBe(4);
  });

  it('has all unique ids', () => {
    const ids = new Set(tiles.map((t) => t.id));
    expect(ids.size).toBe(112);
  });

  it('tags red/blue variants on the configured 5s and leaves the rest of that rank black', () => {
    const p5 = tiles.filter((t) => t.suit === 'p' && t.rank === 5);
    expect(p5.map((t) => t.variant).sort()).toEqual(['black', 'black', 'blue', 'red']);

    const p4 = tiles.filter((t) => t.suit === 'p' && t.rank === 4);
    expect(p4.every((t) => t.variant === null)).toBe(true);
  });

  it('supports a fully custom special tile map', () => {
    const customRules = createRuleConfig({
      RULE_SPECIAL_TILE_MAP: [{ suit: 's', rank: 9, variant: 'red', count: 2 }],
    });
    const customTiles = createTileSet(customRules);
    const s9 = customTiles.filter((t) => t.suit === 's' && t.rank === 9);
    expect(s9.filter((t) => t.variant === 'red').length).toBe(2);
    expect(s9.filter((t) => t.variant === 'black').length).toBe(2);
  });

  it('tags exactly one haku tile as potchi and leaves the other 3 ordinary (no black fallback for honors)', () => {
    const haku = tiles.filter((t) => t.suit === 'z' && t.rank === 5);
    expect(haku.filter((t) => t.variant === 'potchi').length).toBe(1);
    expect(haku.filter((t) => t.variant === null).length).toBe(3);
  });
});
