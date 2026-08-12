// AI weight vector for the CPU's heuristic evaluation function (spec
// section 42). This is the "parameter self-update" learning target:
// SelfPlay.evolveWeights nudges these numbers based on self-play
// outcomes rather than training a neural network.
//
// Only the factors we can currently compute (shanten, dora, a coarse
// yaku-potential heuristic, staying menzen, discard safety) have a
// meaningful default. The rest of spec section 42's evaluation items
// (役満期待値, アリス期待値, シュバ期待値, 順位期待値, オーラス条件) are
// kept as zero-weighted slots — their underlying expected-value
// computations depend on engines not implemented yet (Alice, Shuba,
// yakuman list, ranking). Once those exist, wiring their contribution
// into HandEvaluator and giving these a nonzero starting weight is a
// small change; self-play learning will then adjust them like anything
// else in the vector.
export const DEFAULT_AI_WEIGHTS = {
  shanten: 15,
  dora: 8,
  yakuPotential: 5,
  menzen: 3,
  safety: 6,

  // Forward-looking hooks — always 0 contribution today.
  yakumanPotential: 0,
  aliceExpectation: 0,
  shubaExpectation: 0,
  rankExpectation: 0,
  oorasuBias: 0,
};

export function cloneWeights(weights) {
  return { ...weights };
}

// Additive jitter (not multiplicative) so a currently-zero hook weight
// can still move once its scale is nonzero, instead of staying locked
// at 0 forever. Weights are clamped to >= 0 (they're importances, not
// signed preferences).
export function perturbWeights(weights, { scale = 1, rng = Math.random } = {}) {
  const next = {};
  for (const [key, value] of Object.entries(weights)) {
    const jitter = (rng() * 2 - 1) * scale;
    next[key] = Math.max(0, value + jitter);
  }
  return next;
}
