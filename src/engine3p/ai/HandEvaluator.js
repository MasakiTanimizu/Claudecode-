// HandEvaluator: turns a hand state into a single scalar "value" the
// CPU AI can compare across candidate discards/actions (spec section
// 42). Deliberately reuses the real engine modules (Shanten, DoraHan)
// rather than re-deriving their logic, so the AI's notion of "good"
// stays consistent with how the hand actually scores.

import { shanten as computeShanten } from './Shanten.js';
import { computeDoraHan } from '../scoring/DoraHan.js';
import { isSimple } from '../tiles/Tiles.js';

const YAKUHAI_HONOR_RANKS = new Set([5, 6, 7]);

function estimateYakuPotential(concealedTiles, { roundWind, seatWind }) {
  if (concealedTiles.length === 0) return 0;

  const counts = new Map();
  for (const t of concealedTiles) {
    const key = `${t.suit}${t.rank}`;
    counts.set(key, (counts.get(key) ?? 0) + 1);
  }

  // Tanyao potential: how much of the hand is already simples (0..1).
  let score = concealedTiles.filter(isSimple).length / concealedTiles.length;

  // Yakuhai potential: a pair or triplet of a dragon/round/seat-wind tile.
  for (const [key, n] of counts) {
    if (key[0] !== 'z' || n < 2) continue;
    const rank = Number(key.slice(1));
    if (rank === 4) continue; // north is never yakuhai
    if (YAKUHAI_HONOR_RANKS.has(rank) || rank === roundWind || rank === seatWind) score += 1;
  }

  return score;
}

// ctx: {
//   concealedTiles, meldCount, doraIndicators, uraDoraIndicators,
//   riichiActive, kitaCount, roundWind, seatWind, isMenzen,
// }
export function evaluateHand(ctx, weights) {
  const s = computeShanten(ctx.concealedTiles, ctx.meldCount ?? 0);
  const doraResult = computeDoraHan({
    handTiles: ctx.concealedTiles,
    doraIndicators: ctx.doraIndicators ?? [],
    uraDoraIndicators: ctx.uraDoraIndicators ?? [],
    riichiActive: ctx.riichiActive ?? false,
    kitaCount: ctx.kitaCount ?? 0,
  });
  const yakuPotential = estimateYakuPotential(ctx.concealedTiles, ctx);

  const value = -weights.shanten * s
    + weights.dora * doraResult.total
    + weights.yakuPotential * yakuPotential
    + weights.menzen * (ctx.isMenzen ? 1 : 0);

  return { value, shanten: s, doraResult, yakuPotential };
}
