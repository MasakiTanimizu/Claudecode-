// SpecialBonusRule: 金星・大金星 (spec sections 33-34), implemented as
// its own module per the spec's own instruction ("SpecialBonusRuleとして
// 独立実装する"). Condition per the user's clarification:
//
//   金星: tsumo/ron win exactly on junme 8. Tsumo pays 3 chips from
//         each opponent (6 total); ron pays 3 chips from the discarder.
//   大金星: same shape, junme 16, 5 chips per payer instead of 3.
//
// junme (turn count) is derived from RoundState.totalDiscards — the
// *discard* count, not the draw count. A pon/daiminkan caller discards
// immediately without drawing from the wall, so a wall-draw-based
// counter would silently fall behind whenever a call happens. Counting
// discards instead means every discard — whether it followed a normal
// draw or a call — advances junme, which is what the user meant by
// "捨てる牌の場所" (it's about the discard's position): if the tile
// sitting at the junme-8 slot gets swept up by a pon, the caller's very
// next discard is simply the next discard in sequence and still lands
// on (or past) that same junme value, rather than the count jumping or
// stalling because no wall tile was drawn for that turn.

import { distributeZeroSumChips } from './ChipPayment.js';

export function computeJunme(totalDiscards, playerCount = 3) {
  if (totalDiscards <= 0) return 0;
  return Math.ceil(totalDiscards / playerCount);
}

// multiplier: the active シュバ/シュバゾーマ/シュバンテ multiplier (1 if
// none) — kinsei/daikinsei are 和了り祝儀 like the others, so the same
// multiplier scales both what the winner receives and what payers lose.
export function computeSpecialBonusPayments({
  junme,
  isTsumo,
  winnerSeat,
  discarderSeat,
  seatCount = 3,
  ruleConfig,
  multiplier = 1,
}) {
  let name = null;
  let perPayer = 0;
  if (junme === ruleConfig.RULE_KINSEI_JUNME) {
    name = 'kinsei';
    perPayer = ruleConfig.RULE_CHIP_VALUES.kinsei;
  } else if (junme === ruleConfig.RULE_DAIKINSEI_JUNME) {
    name = 'daikinsei';
    perPayer = ruleConfig.RULE_CHIP_VALUES.daikinsei;
  } else {
    return { deltas: Array.from({ length: seatCount }, () => 0), name: null, total: 0 };
  }

  const { deltas, total } = distributeZeroSumChips(perPayer * multiplier, {
    isTsumo, winnerSeat, discarderSeat, seatCount,
  });
  return { deltas, name, total };
}
