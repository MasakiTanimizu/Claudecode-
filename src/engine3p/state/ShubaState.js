// ShubaState (spec section 36, clarified by the user): each player
// holds exactly one shuba stick, freshly granted at the start of every
// hand, usable at most once that hand to declare シュバ/シュバゾーマ/
// シュバンテ instead of a plain リーチ. It's a per-hand permission
// token, not a pool of real points — spending it doesn't touch anyone's
// score directly (see RuleConfig's note on RULE_SHUBA_STICK_VALUE).

export function createShubaState(playerCount = 3) {
  return {
    availableBySeat: Array.from({ length: playerCount }, () => true),
    tierBySeat: Array.from({ length: playerCount }, () => null), // null | 'shuba' | 'shubazoma' | 'shubante'
  };
}

// Call when a new hand starts (mirrors RoundState.nextRound resetting
// per-hand pools like kyoutakuPoints).
export function resetShubaState(state) {
  return createShubaState(state.availableBySeat.length);
}
