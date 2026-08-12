// ChipEngine: 祝儀 (chip) accounting, kept fully separate from point
// scoring (spec sections 32, 40).
//
// Phase 1/2 scope implements the chip sources that only need the
// winning hand + dora indicators + riichi/kita state: red tiles,
// ippatsu, uradora, kita. Alice, Shuba tiers, 金星/大金星/トリプル,
// counted/pure yakuman, 出目金, and 4花4北 are Phase 4-5 per the
// roadmap (spec section 62); their hooks are present here and return 0
// until those engines are implemented, so ScoreEngine/TurnEngine can
// already call `computeChips` with a stable shape.

import { countDoraMatches } from '../tiles/Dora.js';

export function computeChips(ctx, ruleConfig) {
  const values = ruleConfig.RULE_CHIP_VALUES;
  const breakdown = [];

  const redCount = (ctx.handTiles ?? []).filter((t) => t.variant === 'red').length;
  if (redCount > 0) breakdown.push({ name: 'red', count: redCount, chips: redCount * values.red });

  if (ctx.ippatsu) breakdown.push({ name: 'ippatsu', count: 1, chips: values.ippatsu });

  // Blue tiles are always-hit ura-dora targets (spec section 5), so they
  // fall into the same chip bucket as an actual ura-dora match.
  const uradoraCount = ctx.isMenzen && ctx.riichiActive
    ? countDoraMatches(ctx.handTiles ?? [], ctx.uraDoraIndicators ?? [])
      + (ctx.handTiles ?? []).filter((t) => t.variant === 'blue').length
    : 0;
  if (uradoraCount > 0) breakdown.push({ name: 'uradora', count: uradoraCount, chips: uradoraCount * values.uradora });

  const kitaCount = ctx.kitaCount ?? 0;
  if (kitaCount > 0) breakdown.push({ name: 'kita', count: kitaCount, chips: kitaCount * values.kita });

  // Phase 4/5 hooks — not yet implemented.
  const aliceChips = computeAliceChips(ctx, ruleConfig);
  if (aliceChips > 0) breakdown.push({ name: 'alice', count: aliceChips / values.alice, chips: aliceChips });
  const kinseiChips = computeKinseiChips(ctx, ruleConfig);
  if (kinseiChips > 0) breakdown.push({ name: 'kinsei', count: 1, chips: kinseiChips });

  const subtotal = breakdown.reduce((s, b) => s + b.chips, 0);
  const multiplier = computeShubaMultiplier(ctx, ruleConfig);
  const total = subtotal * multiplier;

  return { breakdown, subtotal, multiplier, total };
}

// Phase 4 — Alice engine not yet implemented.
export function computeAliceChips(_ctx, _ruleConfig) {
  return 0;
}

// Phase 4 — 金星/大金星 (SpecialBonusRule) not yet implemented.
export function computeKinseiChips(_ctx, _ruleConfig) {
  return 0;
}

// Phase 5 — シュバ/シュバゾーマ/シュバンテ倍率. Order per spec section 36:
// normal chips -> alice -> other bonuses -> total -> shuba multiplier.
export function computeShubaMultiplier(ctx, ruleConfig) {
  if (!ctx.isWin) return 1;
  const tier = ctx.shubaTier; // null | 'shuba' | 'shubazoma' | 'shubante'
  if (tier === 'shuba') return ruleConfig.RULE_SHUBA_MULTIPLIER;
  if (tier === 'shubazoma') return ruleConfig.RULE_SHUBA_ZOMA_MULTIPLIER;
  if (tier === 'shubante') return ruleConfig.RULE_SHUBANTE_MULTIPLIER;
  return 1;
}
