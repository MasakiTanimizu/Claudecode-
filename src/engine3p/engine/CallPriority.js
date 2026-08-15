// CallPriority: arbitrates simultaneous claims on a single discard.
//
// House rule (chi is removed entirely, see RuleConfig.RULE_CHI_ENABLED):
// only ron, pon, and kan (daiminkan) claims exist. Ron always outranks
// everything else and multiple simultaneous ron claims are all honored
// (multi-ron; this spec does not mention a head-bump/atama-hane rule,
// so none is applied). Pon and kan share equal priority — when both are
// claimed on the same discard by different players, the tie is broken
// by seating proximity to the discarder (whoever would act first in
// turn order after them wins), not by call type.

function turnDistance(discarderSeat, seat, playerCount) {
  return (seat - discarderSeat + playerCount) % playerCount;
}

// claims: [{ seat, type: 'ron' | 'pon' | 'kan' }], excluding the discarder.
export function resolveCallPriority(discarderSeat, claims, playerCount = 3) {
  const eligible = claims.filter((c) => c.seat !== discarderSeat);

  const ronClaims = eligible.filter((c) => c.type === 'ron');
  if (ronClaims.length > 0) {
    const winners = ronClaims
      .map((c) => c.seat)
      .sort((a, b) => turnDistance(discarderSeat, a, playerCount) - turnDistance(discarderSeat, b, playerCount));
    return { type: 'ron', winners, contested: winners.length > 1 };
  }

  const meldClaims = eligible.filter((c) => c.type === 'pon' || c.type === 'kan');
  if (meldClaims.length === 0) return { type: null, winners: [] };

  const winner = meldClaims.reduce((best, c) => (
    turnDistance(discarderSeat, c.seat, playerCount) < turnDistance(discarderSeat, best.seat, playerCount) ? c : best
  ));
  return { type: winner.type, winners: [winner.seat], contested: meldClaims.length > 1 };
}
