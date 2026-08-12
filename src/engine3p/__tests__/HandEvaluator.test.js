import { describe, it, expect } from 'vitest';
import { evaluateHand } from '../ai/HandEvaluator.js';
import { DEFAULT_AI_WEIGHTS } from '../ai/AIWeights.js';

function t(suit, rank, variant = null) {
  return { suit, rank, variant };
}

function baseCtx(overrides = {}) {
  return {
    concealedTiles: [],
    meldCount: 0,
    doraIndicators: [],
    uraDoraIndicators: [],
    riichiActive: false,
    kitaCount: 0,
    roundWind: 1,
    seatWind: 2,
    isMenzen: true,
    ...overrides,
  };
}

describe('HandEvaluator.evaluateHand', () => {
  it('scores a tenpai hand higher than a far-from-complete hand', () => {
    const tenpai = evaluateHand(baseCtx({
      concealedTiles: [
        t('p', 1), t('p', 2), t('p', 3),
        t('p', 4), t('p', 5), t('p', 6),
        t('p', 7), t('p', 8), t('p', 9),
        t('s', 1), t('s', 2), t('s', 3),
        t('z', 5),
      ],
    }), DEFAULT_AI_WEIGHTS);

    const farFromComplete = evaluateHand(baseCtx({
      concealedTiles: [
        t('m', 1), t('p', 2), t('s', 9),
        t('z', 1), t('z', 3), t('z', 6),
        t('p', 5), t('s', 2), t('m', 9),
        t('z', 7), t('p', 8), t('s', 4), t('z', 2),
      ],
    }), DEFAULT_AI_WEIGHTS);

    expect(tenpai.shanten).toBeLessThan(farFromComplete.shanten);
    expect(tenpai.value).toBeGreaterThan(farFromComplete.value);
  });

  it('adds dora contribution from DoraHan into the value', () => {
    const hand = [
      t('p', 1), t('p', 2), t('p', 3),
      t('p', 4), t('p', 5), t('p', 6),
      t('p', 7), t('p', 8), t('p', 9),
      t('s', 1), t('s', 2), t('s', 3),
      t('z', 5),
    ];
    const withoutDora = evaluateHand(baseCtx({ concealedTiles: hand }), DEFAULT_AI_WEIGHTS);
    const withDora = evaluateHand(baseCtx({ concealedTiles: hand, doraIndicators: [t('p', 1)] }), DEFAULT_AI_WEIGHTS);
    expect(withDora.doraResult.total).toBeGreaterThan(withoutDora.doraResult.total);
    expect(withDora.value).toBeGreaterThan(withoutDora.value);
  });

  it('rewards staying menzen via the menzen weight', () => {
    const hand = [
      t('p', 1), t('p', 2), t('p', 3),
      t('p', 4), t('p', 5), t('p', 6),
      t('p', 7), t('p', 8), t('p', 9),
      t('s', 1), t('s', 2), t('s', 3),
      t('z', 5),
    ];
    const menzen = evaluateHand(baseCtx({ concealedTiles: hand, isMenzen: true }), DEFAULT_AI_WEIGHTS);
    const open = evaluateHand(baseCtx({ concealedTiles: hand, isMenzen: false }), DEFAULT_AI_WEIGHTS);
    expect(menzen.value - open.value).toBe(DEFAULT_AI_WEIGHTS.menzen);
  });

  it('ignores forward-looking zero-weight hooks without crashing', () => {
    const result = evaluateHand(baseCtx({ concealedTiles: [t('p', 4)] }), DEFAULT_AI_WEIGHTS);
    expect(Number.isFinite(result.value)).toBe(true);
  });
});
