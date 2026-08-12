// RoundState: per-hand state, including honba/shuraba progression
// (spec sections 9-10).

export function createRoundState({ roundWind = 1, roundNumber = 1, dealerSeat = 0 } = {}) {
  return {
    roundWind, // 1 = East (東風戦なので東場のみ想定)
    roundNumber, // 東1局 = 1, 東2局 = 2, ...
    dealerSeat,
    honba: 0,
    riichiSticks: 0,
    shurabaCount: 0,
    doraIndicators: [],
    uraDoraIndicators: [],
    turn: 0,
  };
}

// Shuraba (修羅場): honba advances every hand regardless of a plain
// dealer-repeat, on top of any dealer-continuation honba. The exact
// cadence is configurable so it can be tuned without touching the engine.
export function advanceShuraba(round, ruleConfig) {
  const step = ruleConfig.RULE_SHURABA_HONBA_STEP ?? 1;
  return {
    ...round,
    shurabaCount: round.shurabaCount + 1,
    honba: round.honba + step,
  };
}

export function nextRound(round, { dealerContinues, dealerSeat }) {
  return {
    ...round,
    roundNumber: dealerContinues ? round.roundNumber : round.roundNumber + 1,
    dealerSeat,
    honba: dealerContinues ? round.honba + 1 : round.honba,
    riichiSticks: 0,
    turn: 0,
    doraIndicators: [],
    uraDoraIndicators: [],
  };
}
