// ScoreState / ChipState / RankPoint / Bonus are managed as separate
// values per spec section 12 ("完全順位制"): Score, Chip, RankPoint and
// Bonus never mix in a single number.

export function createScoreState(playerCount, ruleConfig) {
  return Array.from({ length: playerCount }, () => ruleConfig.RULE_STARTING_SCORE);
}

export function createChipState(playerCount) {
  return Array.from({ length: playerCount }, () => 0);
}

export function applyScoreDelta(scores, deltas) {
  return scores.map((s, i) => s + (deltas[i] ?? 0));
}

export function applyChipDelta(chips, deltas) {
  return chips.map((c, i) => c + (deltas[i] ?? 0));
}

// Converts an integer score into the special denomination point-stick
// display (80000 / 90000 / 100000) without changing the underlying
// integer score used for calculations (spec section 13).
export function toStickDisplay(score, ruleConfig) {
  const units = [...(ruleConfig.RULE_SCORE_UNITS ?? [])].sort((a, b) => b.value - a.value);
  let remaining = score;
  const sticks = [];
  for (const unit of units) {
    while (remaining >= unit.value) {
      sticks.push(unit.value);
      remaining -= unit.value;
    }
  }
  if (remaining !== 0 || sticks.length === 0) sticks.push(remaining);
  return sticks;
}
