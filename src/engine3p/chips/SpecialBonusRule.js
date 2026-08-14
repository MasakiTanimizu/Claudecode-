// SpecialBonusRule: 金星・大金星 (spec sections 33-34), implemented as
// its own module per the spec's own instruction ("SpecialBonusRuleとして
//独立実装する"). Condition per the user's clarification:
//
//   金星: tsumo/ron win exactly on junme 8. Tsumo pays 3 chips from
//         each opponent (6 total); ron pays 3 chips from the discarder.
//   大金星: same shape, junme 16, 5 chips per payer instead of 3.
//
// Unlike the other chip categories implemented so far (red, ippatsu,
// uradora, kita, yakuman — all credited to the winner from an abstract
// pool), kinsei/daikinsei are an explicit zero-sum transfer: the
// user described ron as "obtaining 3 FROM the discarder", so the
// payer(s) actually lose chips, not just the winner gaining them.
//
// junme (turn count) is derived from RoundState.totalDraws, which only
// advances on genuine live-wall draws (TurnEngine.drawForTurn) — kan/
// kita/hana replacement draws use drawReplacement instead and don't
// touch it. That's what makes it survive pon/kan skipping the normal
// turn order, per the user's note ("ポン、カンにより流れてもじゅんめは
// 適用される") — junme tracks wall depth, not whose turn it "should" be.

export function computeJunme(totalDraws, playerCount = 3) {
  if (totalDraws <= 0) return 0;
  return Math.ceil(totalDraws / playerCount);
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
  const deltas = Array.from({ length: seatCount }, () => 0);

  let name = null;
  let perPayer = 0;
  if (junme === ruleConfig.RULE_KINSEI_JUNME) {
    name = 'kinsei';
    perPayer = ruleConfig.RULE_CHIP_VALUES.kinsei;
  } else if (junme === ruleConfig.RULE_DAIKINSEI_JUNME) {
    name = 'daikinsei';
    perPayer = ruleConfig.RULE_CHIP_VALUES.daikinsei;
  } else {
    return { deltas, name: null, total: 0 };
  }

  const scaledPerPayer = perPayer * multiplier;

  if (isTsumo) {
    for (let s = 0; s < seatCount; s++) {
      if (s === winnerSeat) continue;
      deltas[s] -= scaledPerPayer;
      deltas[winnerSeat] += scaledPerPayer;
    }
  } else {
    deltas[discarderSeat] -= scaledPerPayer;
    deltas[winnerSeat] += scaledPerPayer;
  }

  return { deltas, name, total: deltas[winnerSeat] };
}
