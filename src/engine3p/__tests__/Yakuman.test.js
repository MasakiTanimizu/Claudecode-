import { describe, it, expect } from 'vitest';
import { detectYakuman, usesNorthTile } from '../yaku/Yakuman.js';

function t(suit, rank) {
  return { suit, rank };
}

function baseCtx(overrides = {}) {
  return {
    concealedTiles: [],
    calledMelds: [],
    winTile: null,
    isTsumo: false,
    isFirstUninterruptedDraw: false,
    isDealer: false,
    ...overrides,
  };
}

describe('Yakuman.detectYakuman', () => {
  it('detects kokushi musou and flags it as north-eligible', () => {
    const ctx = baseCtx({
      concealedTiles: [
        t('m', 1), t('m', 1), t('m', 9), t('p', 1), t('p', 9),
        t('s', 1), t('s', 9), t('z', 1), t('z', 2), t('z', 3),
        t('z', 4), t('z', 5), t('z', 6), t('z', 7),
      ],
    });
    const result = detectYakuman(ctx);
    expect(result.names).toContain('国士無双');
    expect(result.northEligible).toBe(true);
  });

  it('detects suuankou (四暗刻) on a tsumo win with 4 concealed triplets', () => {
    const ctx = baseCtx({
      concealedTiles: [
        t('m', 1), t('m', 1), t('m', 1),
        t('s', 1), t('s', 1), t('s', 1),
        t('z', 6), t('z', 6), t('z', 6),
        t('z', 5), t('z', 5), t('z', 5),
        t('p', 8), t('p', 8),
      ],
      isTsumo: true,
    });
    expect(detectYakuman(ctx).names).toContain('四暗刻');
  });

  it('rejects suuankou on a ron that completes a triplet instead of the pair', () => {
    const ctx = baseCtx({
      concealedTiles: [
        t('m', 1), t('m', 1), t('m', 1),
        t('s', 1), t('s', 1), t('s', 1),
        t('z', 6), t('z', 6), t('z', 6),
        t('z', 5), t('z', 5), t('z', 5),
        t('p', 8), t('p', 8),
      ],
      isTsumo: false,
      winTile: t('z', 5),
    });
    expect(detectYakuman(ctx).names).not.toContain('四暗刻');
  });

  it('detects daisangen (大三元): all 3 dragon triplets', () => {
    const ctx = baseCtx({
      concealedTiles: [
        t('z', 5), t('z', 5), t('z', 5),
        t('z', 6), t('z', 6), t('z', 6),
        t('z', 7), t('z', 7), t('z', 7),
        t('p', 1), t('p', 2), t('p', 3),
        t('m', 1), t('m', 1),
      ],
    });
    expect(detectYakuman(ctx).names).toContain('大三元');
  });

  it('detects tsuuiisou (字一色), allowing north as a legitimate hand tile', () => {
    const ctx = baseCtx({
      concealedTiles: [
        t('z', 5), t('z', 5), t('z', 5),
        t('z', 6), t('z', 6), t('z', 6),
        t('z', 7), t('z', 7), t('z', 7),
        t('z', 1), t('z', 1), t('z', 1),
        t('z', 4), t('z', 4),
      ],
    });
    const result = detectYakuman(ctx);
    expect(result.names).toContain('字一色');
    expect(result.northEligible).toBe(true);
    expect(usesNorthTile(ctx.concealedTiles, ctx.calledMelds)).toBe(true);
  });

  it('detects shousuushii (小四喜): 3 wind triplets + north as the pair', () => {
    const ctx = baseCtx({
      concealedTiles: [
        t('z', 1), t('z', 1), t('z', 1),
        t('z', 2), t('z', 2), t('z', 2),
        t('z', 3), t('z', 3), t('z', 3),
        t('p', 1), t('p', 2), t('p', 3),
        t('z', 4), t('z', 4),
      ],
    });
    const result = detectYakuman(ctx);
    expect(result.names).toContain('小四喜');
    expect(result.names).not.toContain('字一色');
    expect(result.northEligible).toBe(true);
  });

  it('detects daisuushii (大四喜): all 4 winds as triplets, including north', () => {
    const ctx = baseCtx({
      concealedTiles: [
        t('z', 1), t('z', 1), t('z', 1),
        t('z', 2), t('z', 2), t('z', 2),
        t('z', 3), t('z', 3), t('z', 3),
        t('z', 4), t('z', 4), t('z', 4),
        t('m', 1), t('m', 1),
      ],
    });
    const result = detectYakuman(ctx);
    expect(result.names).toContain('大四喜');
    expect(result.northEligible).toBe(true);
  });

  it('detects chinroutou (清老頭): every tile is a terminal', () => {
    const ctx = baseCtx({
      concealedTiles: [
        t('m', 1), t('m', 1), t('m', 1),
        t('m', 9), t('m', 9), t('m', 9),
        t('p', 1), t('p', 1), t('p', 1),
        t('p', 9), t('p', 9), t('p', 9),
        t('s', 1), t('s', 1),
      ],
    });
    expect(detectYakuman(ctx).names).toContain('清老頭');
  });

  it('detects ryuuiisou (緑一色): only the green tiles (sou 2/3/4/6/8 + hatsu)', () => {
    const ctx = baseCtx({
      concealedTiles: [
        t('s', 2), t('s', 2), t('s', 2),
        t('s', 3), t('s', 3), t('s', 3),
        t('s', 4), t('s', 4), t('s', 4),
        t('z', 6), t('z', 6), t('z', 6),
        t('s', 6), t('s', 6),
      ],
    });
    expect(detectYakuman(ctx).names).toContain('緑一色');
  });

  it('detects suukantsu (四槓子): 4 called kans', () => {
    const ctx = baseCtx({
      concealedTiles: [t('m', 1), t('m', 1)],
      calledMelds: [
        { type: 'kan', suit: 'p', rank: 1, concealed: false },
        { type: 'kan', suit: 'p', rank: 9, concealed: false },
        { type: 'kan', suit: 's', rank: 1, concealed: true },
        { type: 'kan', suit: 'z', rank: 5, concealed: false },
      ],
    });
    expect(detectYakuman(ctx).names).toContain('四槓子');
  });

  it('detects suurenkou (四連刻): 4 consecutive-rank triplets, same suit', () => {
    const ctx = baseCtx({
      concealedTiles: [
        t('p', 3), t('p', 3), t('p', 3),
        t('p', 4), t('p', 4), t('p', 4),
        t('p', 5), t('p', 5), t('p', 5),
        t('p', 6), t('p', 6), t('p', 6),
        t('z', 5), t('z', 5),
      ],
    });
    expect(detectYakuman(ctx).names).toContain('四連刻');
  });

  it('detects manzu honitsu (萬子の混一色): man + honors, at least one man tile', () => {
    const ctx = baseCtx({
      concealedTiles: [
        t('m', 1), t('m', 1), t('m', 1),
        t('m', 9), t('m', 9), t('m', 9),
        t('z', 5), t('z', 5), t('z', 5),
        t('z', 6), t('z', 6), t('z', 6),
        t('z', 7), t('z', 7),
      ],
    });
    const result = detectYakuman(ctx);
    expect(result.names).toContain('萬子の混一色');
    expect(result.names).not.toContain('字一色');
  });

  it('detects chinitsu chiitoitsu (清一色七対子): 7 pairs, single suit', () => {
    const ctx = baseCtx({
      concealedTiles: [
        t('p', 1), t('p', 1), t('p', 2), t('p', 2),
        t('p', 3), t('p', 3), t('p', 4), t('p', 4),
        t('p', 5), t('p', 5), t('p', 6), t('p', 6),
        t('p', 7), t('p', 7),
      ],
    });
    expect(detectYakuman(ctx).names).toContain('清一色七対子');
  });

  it('detects tenhou for the dealer and chiihou for a non-dealer, both requiring an uninterrupted first draw', () => {
    const hand = [
      t('p', 1), t('p', 2), t('p', 3),
      t('p', 4), t('p', 5), t('p', 6),
      t('s', 7), t('s', 8), t('s', 9),
      t('m', 1), t('m', 1), t('m', 1),
      t('z', 5), t('z', 5),
    ];
    const tenhou = detectYakuman(baseCtx({ concealedTiles: hand, isTsumo: true, isFirstUninterruptedDraw: true, isDealer: true }));
    expect(tenhou.names).toContain('天和');

    const chiihou = detectYakuman(baseCtx({ concealedTiles: hand, isTsumo: true, isFirstUninterruptedDraw: true, isDealer: false }));
    expect(chiihou.names).toContain('地和');

    const notFirstDraw = detectYakuman(baseCtx({ concealedTiles: hand, isTsumo: true, isFirstUninterruptedDraw: false, isDealer: true }));
    expect(notFirstDraw.names).not.toContain('天和');
  });

  it('reports isYakuman false and an empty name list for an ordinary hand', () => {
    const ctx = baseCtx({
      concealedTiles: [
        t('p', 2), t('p', 3), t('p', 4),
        t('s', 5), t('s', 6), t('s', 7),
        t('m', 1), t('m', 1), t('m', 1),
        t('p', 7), t('p', 8), t('p', 9),
        t('s', 2), t('s', 2),
      ],
    });
    const result = detectYakuman(ctx);
    expect(result.isYakuman).toBe(false);
    expect(result.names).toEqual([]);
    expect(result.northEligible).toBe(false);
  });
});

describe('Yakuman.usesNorthTile', () => {
  it('detects north among concealed tiles or called melds', () => {
    expect(usesNorthTile([t('z', 4)], [])).toBe(true);
    expect(usesNorthTile([], [{ suit: 'z', rank: 4 }])).toBe(true);
    expect(usesNorthTile([t('z', 1)], [])).toBe(false);
  });
});
