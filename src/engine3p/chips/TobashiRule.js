// TobashiRule: トバし (spec section 32/35), condition per the user's
// clarification:
//
//   - A score of exactly 0 counts as busted too ("0点もトビ扱い"), not
//     just negative.
//   - The busted player pays the player who busted them.
//   - If a single win busts two opponents at once (a large tsumo can
//     drop both), each pays the winner 10 chips independently
//     ("2人のプレイヤーが1人のプレイヤーに飛ばされた場合、10枚ずつ
//     飛ばしたプレイヤーに支払う").
//
// Detected as a >0 -> <=0 transition caused by this win's payments
// (score + honba + kyoutaku collection), not merely "is currently
// <=0" — a player already busted from an earlier hand shouldn't be
// charged again just for losing further points, since nothing new
// "happened" to them this time.

export function computeTobashiPayments({
  scoresBefore,
  scoresAfter,
  winnerSeat,
  ruleConfig,
  multiplier = 1,
  seatCount = 3,
}) {
  const deltas = Array.from({ length: seatCount }, () => 0);
  const bustedSeats = [];
  const perBust = ruleConfig.RULE_CHIP_VALUES.tobashi * multiplier;

  for (let s = 0; s < seatCount; s++) {
    if (s === winnerSeat) continue;
    if (scoresBefore[s] > 0 && scoresAfter[s] <= 0) {
      bustedSeats.push(s);
      deltas[s] -= perBust;
      deltas[winnerSeat] += perBust;
    }
  }

  return { deltas, bustedSeats };
}
