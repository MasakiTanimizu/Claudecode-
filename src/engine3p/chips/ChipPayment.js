// ChipPayment: shared zero-sum settlement pattern for 祝儀 (chips).
//
// Per the user's confirmation, every chip category in this ruleset
// (red tiles, ippatsu, uradora, kita, yakuman, hana, kinsei/daikinsei —
// everything computed in ChipEngine.computeChips plus
// SpecialBonusRule) is paid FROM the loser(s) TO the winner, not
// credited from an abstract pool: a tsumo win collects `perPayer` chips
// from *each* opponent individually (so the winner's total scales with
// opponent count, e.g. "3枚ずつ計6枚" for a 2-opponent tsumo), while a
// ron win collects the full `perPayer` amount from the discarder alone.
// This mirrors how real cash-chip mahjong settles 祝儀, and is distinct
// from how ScoreEngine splits point payments (which divides a fixed
// total proportionally rather than having each opponent pay the same
// figure in full).

export function distributeZeroSumChips(perPayer, {
  isTsumo,
  winnerSeat,
  discarderSeat,
  seatCount = 3,
}) {
  const deltas = Array.from({ length: seatCount }, () => 0);
  if (perPayer === 0) return { deltas, total: 0 };

  if (isTsumo) {
    for (let s = 0; s < seatCount; s++) {
      if (s === winnerSeat) continue;
      deltas[s] -= perPayer;
      deltas[winnerSeat] += perPayer;
    }
  } else {
    deltas[discarderSeat] -= perPayer;
    deltas[winnerSeat] += perPayer;
  }

  return { deltas, total: deltas[winnerSeat] };
}
