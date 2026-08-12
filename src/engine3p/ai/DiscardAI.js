// DiscardAI: picks which tile to discard by evaluating the resulting
// hand for every candidate, plus a discard-safety bonus (spec section
// 42's 放銃率 factor) using genbutsu (a tile already in an opponent's
// own discard pile is safe against that specific opponent per the
// furiten rule).

import { evaluateHand } from './HandEvaluator.js';

function genbutsuSafety(tile, opponentsDiscards) {
  if (!opponentsDiscards || opponentsDiscards.length === 0) return 0;
  const safeAgainst = opponentsDiscards.filter((discards) => discards.some((d) => d.suit === tile.suit && d.rank === tile.rank)).length;
  return safeAgainst / opponentsDiscards.length;
}

// ctx: same shape as HandEvaluator's ctx, but `hand` holds the full
// tile set to choose a discard from (concealedTiles is derived per
// candidate). `opponentsDiscards`: array of each opponent's discard
// tile list.
export function chooseDiscard(ctx, weights) {
  const { hand, meldCount = 0, opponentsDiscards = [] } = ctx;
  if (hand.length === 0) throw new Error('Cannot choose a discard from an empty hand');

  const evaluations = hand.map((candidate, index) => {
    const remaining = hand.filter((_, i) => i !== index);
    const handValue = evaluateHand({ ...ctx, concealedTiles: remaining, meldCount }, weights);
    const safety = genbutsuSafety(candidate, opponentsDiscards);
    const value = handValue.value + weights.safety * safety;
    return { tile: candidate, value, handValue, safety };
  });

  evaluations.sort((a, b) => b.value - a.value);
  const best = evaluations[0];

  return { tileId: best.tile.id, tile: best.tile, value: best.value, evaluations };
}
