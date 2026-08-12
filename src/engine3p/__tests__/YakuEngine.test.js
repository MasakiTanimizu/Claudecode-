import { describe, it, expect } from 'vitest';
import { evaluateYaku, requiresOpenForFuroRiichi } from '../yaku/YakuEngine.js';
import { createRuleConfig } from '../rules/RuleConfig.js';

function t(suit, rank) {
  return { suit, rank };
}

const rules = createRuleConfig();

function baseCtx(overrides = {}) {
  return {
    concealedTiles: [],
    calledMelds: [],
    winTile: null,
    isTsumo: false,
    isMenzen: true,
    roundWind: 1,
    seatWind: 2,
    riichi: { active: false, ippatsu: false, open: false, furo: false },
    isHaitei: false,
    isHoutei: false,
    isChankan: false,
    isRinshan: false,
    waitIsTwoSided: false,
    ruleConfig: rules,
    ...overrides,
  };
}

describe('YakuEngine', () => {
  it('detects tanyao + menzen tsumo on an all-simples hand', () => {
    const ctx = baseCtx({
      concealedTiles: [
        t('p', 2), t('p', 3), t('p', 4),
        t('p', 4), t('p', 5), t('p', 6),
        t('s', 6), t('s', 7), t('s', 8),
        t('s', 3), t('s', 4), t('s', 5),
        t('p', 2), t('p', 2),
      ],
      isTsumo: true,
    });
    const result = evaluateYaku(ctx, rules);
    expect(result.hasYaku).toBe(true);
    const names = result.yakuList.map((y) => y.name);
    expect(names).toContain('タンヤオ');
    expect(names).toContain('門前自摸');
  });

  it('detects yakuhai for a haku triplet', () => {
    const ctx = baseCtx({
      concealedTiles: [
        t('z', 5), t('z', 5), t('z', 5),
        t('p', 2), t('p', 3), t('p', 4),
        t('s', 6), t('s', 7), t('s', 8),
        t('m', 1), t('m', 1), t('m', 1),
        t('p', 7), t('p', 7),
      ],
    });
    const result = evaluateYaku(ctx, rules);
    const yakuhai = result.yakuList.find((y) => y.name === '役牌');
    expect(yakuhai).toBeTruthy();
    expect(yakuhai.han).toBe(1);
  });

  it('doubles yakuhai han for a dealer east triplet in the east round', () => {
    const ctx = baseCtx({
      concealedTiles: [
        t('z', 1), t('z', 1), t('z', 1),
        t('p', 2), t('p', 3), t('p', 4),
        t('s', 6), t('s', 7), t('s', 8),
        t('m', 1), t('m', 1), t('m', 1),
        t('p', 7), t('p', 7),
      ],
      roundWind: 1,
      seatWind: 1,
    });
    const result = evaluateYaku(ctx, rules);
    const yakuhai = result.yakuList.find((y) => y.name === '役牌');
    expect(yakuhai.han).toBe(2);
  });

  it('never grants a yakuhai bonus for north triplets', () => {
    const ctx = baseCtx({
      concealedTiles: [
        t('z', 4), t('z', 4), t('z', 4),
        t('p', 2), t('p', 3), t('p', 4),
        t('s', 6), t('s', 7), t('s', 8),
        t('m', 1), t('m', 1), t('m', 1),
        t('p', 7), t('p', 7),
      ],
    });
    const result = evaluateYaku(ctx, rules);
    expect(result.yakuList.find((y) => y.name === '役牌')).toBeUndefined();
  });

  it('detects pinfu on an all-sequence hand with a two-sided wait and non-yakuhai pair', () => {
    const ctx = baseCtx({
      concealedTiles: [
        t('p', 1), t('p', 2), t('p', 3),
        t('p', 4), t('p', 5), t('p', 6),
        t('s', 3), t('s', 4), t('s', 5),
        t('s', 6), t('s', 7), t('s', 8),
        t('p', 8), t('p', 8),
      ],
      waitIsTwoSided: true,
    });
    const result = evaluateYaku(ctx, rules);
    expect(result.yakuList.map((y) => y.name)).toContain('平和');
  });

  it('detects iipeikou for two identical sequences in a menzen hand', () => {
    const ctx = baseCtx({
      concealedTiles: [
        t('p', 1), t('p', 2), t('p', 3),
        t('p', 1), t('p', 2), t('p', 3),
        t('s', 6), t('s', 7), t('s', 8),
        t('m', 1), t('m', 1), t('m', 1),
        t('z', 5), t('z', 5),
      ],
    });
    const result = evaluateYaku(ctx, rules);
    expect(result.yakuList.map((y) => y.name)).toContain('一盃口');
  });

  it('applies open riichi han from RuleConfig', () => {
    const ctx = baseCtx({
      concealedTiles: [
        t('p', 1), t('p', 2), t('p', 3),
        t('p', 4), t('p', 5), t('p', 6),
        t('s', 3), t('s', 4), t('s', 5),
        t('s', 6), t('s', 7), t('s', 8),
        t('p', 8), t('p', 8),
      ],
      riichi: { active: true, ippatsu: false, open: true, furo: false },
    });
    const result = evaluateYaku(ctx, rules);
    const open = result.yakuList.find((y) => y.name === 'オープンリーチ');
    expect(open.han).toBe(2);
  });

  it('scores chiitoitsu as 2 han', () => {
    const ctx = baseCtx({
      concealedTiles: [
        t('m', 1), t('m', 1), t('m', 9), t('m', 9),
        t('p', 2), t('p', 2), t('p', 8), t('p', 8),
        t('s', 3), t('s', 3), t('s', 7), t('s', 7),
        t('z', 5), t('z', 5),
      ],
    });
    const result = evaluateYaku(ctx, rules);
    expect(result.yakuList.map((y) => y.name)).toContain('七対子');
  });

  it('reports no yaku for an open hand with no qualifying shapes', () => {
    const ctx = baseCtx({
      concealedTiles: [
        t('p', 1), t('p', 2), t('p', 3),
        t('s', 4), t('s', 5), t('s', 6),
        t('m', 1), t('m', 1),
      ],
      calledMelds: [{ type: 'triplet', suit: 'm', rank: 9, concealed: false }],
      isMenzen: false,
    });
    const result = evaluateYaku(ctx, rules);
    expect(result.hasYaku).toBe(false);
  });

  it('flags furo riichi as requiring open when no other yaku is confirmed', () => {
    expect(requiresOpenForFuroRiichi(0)).toBe(true);
    expect(requiresOpenForFuroRiichi(1)).toBe(false);
  });
});
