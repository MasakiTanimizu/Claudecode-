// DemekinRule: 出目金 (spec section 35), condition per the user's
// clarification. Trigger (win time only, additional to the normal
// chip categories already paid for the same win):
//
//   純正役満 (a structural yakuman, not a counted one) / 4花 (the
//   winner personally extracted all 4 flower tiles) / 4北 (the winner
//   personally extracted all 4 north tiles) / 即白ポッチ (the haku-
//   potchi tile was revealed before riichi was ever declared this hand)
//
// On trigger, roll a die (DiceEngine.rollDice) and settle that many
// chips zero-sum, same tsumo/ron pattern as every other chip category
// now uses (spec section 36's shuba multiplier applies here too, since
// this is 和了り祝儀 like the rest): ロンの場合、放銃者から和了ったプレ
// イヤーに支払い / ツモの場合、対戦相手それぞれが出た目の数だけ支払う
// ("例えばサイコロ2が出れば2枚ずつ支払う").
//
// Only one roll per win even if multiple conditions happen to be true
// simultaneously (spec doesn't describe stacking multiple demekin
// rolls, so this follows the same no-stacking assumption already made
// for overlapping yakuman shapes).

import { distributeZeroSumChips } from './ChipPayment.js';

export function isDemekinTriggered({
  isPureYakuman,
  fourFlowers,
  fourKita,
  isImmediateHakuPotchi,
}) {
  return Boolean(isPureYakuman || fourFlowers || fourKita || isImmediateHakuPotchi);
}

export function computeDemekinPayment({
  diceValue,
  isTsumo,
  winnerSeat,
  discarderSeat,
  seatCount = 3,
  multiplier = 1,
}) {
  return distributeZeroSumChips(diceValue * multiplier, {
    isTsumo, winnerSeat, discarderSeat, seatCount,
  });
}
