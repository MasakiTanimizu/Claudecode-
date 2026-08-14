// ChipEngine: 祝儀 (chip) accounting, kept fully separate from point
// scoring (spec sections 32, 40).
//
// Implements the chip sources that only need the winning hand + dora
// indicators + riichi/kita/yakuman/hana state: red tiles, ippatsu,
// uradora, kita, pure/counted yakuman (section 32's 純正役満/数え役満
// tiers, doubled when 夏 is active), hana chips, and the シュバ/
// シュバゾーマ/シュバンテ multiplier (applied to everything above,
// per the user's clarification that it covers 和了り祝儀・華牌祝儀・
// トビ). 金星/大金星 live in SpecialBonusRule.js instead (their own
// junme-based condition). Alice, トリプル, 出目金, and 4花4北 are still
// later-phase hooks that return 0 until their own engines exist.
//
// The returned `total` is the ron-equivalent/per-payer amount, not a
// flat credit to the winner — per the user's confirmation, every chip
// category here is a zero-sum transfer from the loser(s), matching
// 金星/大金星's settlement. The actual multi-seat distribution (tsumo:
// each opponent pays `total` in full; ron: only the discarder pays)
// happens in TurnEngine.resolveWin via ChipPayment.distributeZeroSumChips,
// not in this function — computeChips only needs to know the winning
// hand, not who's sitting where.
//
// Hana chips need special handling: they're paid out immediately at
// extraction time (spec section 29, before anyone knows if a shuba
// win is coming), so only the *incremental* multiplier-driven top-up
// is owed here — see the hana accounting below.

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

  // spec section 32: 純正役満(pure)/数え役満(counted), doubled tier when
  // 夏 is active. isPureYakuman/isCountedYakuman are mutually exclusive.
  let yakumanChips = 0;
  if (ctx.isPureYakuman) {
    yakumanChips = ctx.summerActive ? values.pureYakumanNatsu : values.pureYakuman;
  } else if (ctx.isCountedYakuman) {
    yakumanChips = ctx.summerActive ? values.countedYakumanNatsu : values.countedYakuman;
  }
  if (yakumanChips > 0) breakdown.push({ name: 'yakuman', count: 1, chips: yakumanChips });

  // spec section 29: already paid out at 1x when extracted; included in
  // the multiplied subtotal below, then netted back out so only the
  // incremental top-up (if any) is what `total` actually owes now.
  const hanaChips = ctx.hanaChips ?? 0;
  if (hanaChips > 0) breakdown.push({ name: 'hana', count: hanaChips, chips: hanaChips });

  // Phase 4 hooks — not yet implemented.
  const aliceChips = computeAliceChips(ctx, ruleConfig);
  if (aliceChips > 0) breakdown.push({ name: 'alice', count: aliceChips / values.alice, chips: aliceChips });
  const kinseiChips = computeKinseiChips(ctx, ruleConfig);
  if (kinseiChips > 0) breakdown.push({ name: 'kinsei', count: 1, chips: kinseiChips });

  const subtotal = breakdown.reduce((s, b) => s + b.chips, 0);
  const multiplier = computeShubaMultiplier(ctx, ruleConfig);
  const total = subtotal * multiplier - hanaChips;

  return { breakdown, subtotal, multiplier, alreadyPaid: hanaChips, total };
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
