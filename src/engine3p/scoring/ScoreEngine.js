// ScoreEngine: dedicated point-calculation engine for the 3-player
// ruleset (spec section 39). Does not reuse a generic 4-player scoring
// table verbatim — fu/base-point math follows the standard formula, but
// payment splitting implements this game's explicit "ツモ損なし" rule
// (tsumo never nets the winner less than an equivalent ron) and its
// custom fixed honba/noten amounts (section 9).

const YAKUHAI_HONOR_RANKS = new Set([5, 6, 7]);

function isHonorOrTerminalSet(meld) {
  if (meld.suit === 'z' || meld.suit === 'm') return true;
  return meld.rank === 1 || meld.rank === 9;
}

function meldFu(meld, ctx) {
  if (meld.type === 'sequence') return 0;
  const containsWinTile = ctx.winTile && ctx.winTile.suit === meld.suit && ctx.winTile.rank === meld.rank;
  const ronCompleted = containsWinTile && !ctx.isTsumo;
  const isOpen = meld.concealed === false || ronCompleted;
  const honorOrTerminal = isHonorOrTerminalSet(meld);
  if (meld.type === 'kan') {
    if (honorOrTerminal) return isOpen ? 16 : 32;
    return isOpen ? 8 : 16;
  }
  // triplet
  if (honorOrTerminal) return isOpen ? 4 : 8;
  return isOpen ? 2 : 4;
}

function pairFu(pair, ctx) {
  if (!pair || pair.suit !== 'z' || pair.rank === 4) return 0;
  if (YAKUHAI_HONOR_RANKS.has(pair.rank)) return 2;
  let fu = 0;
  if (pair.rank === ctx.roundWind) fu += 2;
  if (pair.rank === ctx.seatWind) fu += 2;
  return fu;
}

// decomposition: { melds, pair } from HandParser, for the concealed part
// of the hand. calledMelds: melds already on the table.
// ctx: { isTsumo, isMenzen, winTile, roundWind, seatWind, hasPinfu, isChiitoitsu }
export function computeFu(decomposition, calledMelds, ctx) {
  if (ctx.isChiitoitsu) return 25;
  if (ctx.hasPinfu) return ctx.isTsumo ? 20 : 30;

  let fu = 20;
  for (const meld of decomposition.melds) fu += meldFu(meld, ctx);
  for (const meld of calledMelds) fu += meldFu(meld, ctx);
  fu += pairFu(decomposition.pair, ctx);
  fu += ctx.waitIsTwoSided ? 0 : 2;
  fu += ctx.isTsumo ? 2 : 0;
  if (!ctx.isTsumo && ctx.isMenzen) fu += 10;

  return Math.ceil(fu / 10) * 10;
}

export const MANGAN_PLUS_TABLE = [
  { minHan: 13, base: 8000 }, // 純正/数え役満
  { minHan: 11, base: 6000 }, // 三倍満
  { minHan: 8, base: 4000 }, // 倍満
  { minHan: 6, base: 3000 }, // 跳満
  { minHan: 5, base: 2000 }, // 満貫
];

function roundUp100(n) {
  return Math.ceil(n / 100) * 100;
}

export function computeBasePoints(fu, han) {
  const fixed = MANGAN_PLUS_TABLE.find((t) => han >= t.minHan);
  if (fixed) return fixed.base;
  const base = fu * 2 ** (2 + han);
  return Math.min(base, 2000);
}

// Splits `total` into shares proportional to `weights`, rounding every
// individual share UP to the nearest 100. This is what guarantees tsumo
// payouts are never lower than the equivalent ron total — each payer's
// share is rounded in the winner's favor independently.
function proportionalRoundedShares(total, weights) {
  const weightSum = weights.reduce((a, b) => a + b, 0);
  return weights.map((w) => roundUp100((total * w) / weightSum));
}

export function computeWinPayments({
  fu,
  han,
  isDealer,
  isTsumo,
  winnerSeat,
  dealerSeat,
  discarderSeat, // required when !isTsumo
  seatCount = 3,
  forcedBase,
}) {
  const base = forcedBase ?? computeBasePoints(fu, han);
  const ronTotal = roundUp100(base * (isDealer ? 6 : 4));

  const deltas = Array.from({ length: seatCount }, () => 0);

  if (!isTsumo) {
    deltas[winnerSeat] += ronTotal;
    deltas[discarderSeat] -= ronTotal;
    return { deltas, total: ronTotal, base };
  }

  const opponents = Array.from({ length: seatCount }, (_, s) => s).filter((s) => s !== winnerSeat);
  const weights = opponents.map((s) => (isDealer ? 1 : (s === dealerSeat ? 2 : 1)));
  const shares = proportionalRoundedShares(ronTotal, weights);

  let received = 0;
  opponents.forEach((s, i) => {
    deltas[s] -= shares[i];
    received += shares[i];
  });
  deltas[winnerSeat] += received;

  return { deltas, total: received, base };
}

export function applyHonba(deltas, {
  honba,
  isTsumo,
  winnerSeat,
  discarderSeat,
  seatCount = 3,
  ruleConfig,
}) {
  if (honba <= 0) return deltas;
  const next = [...deltas];

  if (isTsumo) {
    const perOpponent = ruleConfig.RULE_HONBA_TSUMO * honba;
    for (let s = 0; s < seatCount; s++) {
      if (s === winnerSeat) continue;
      next[s] -= perOpponent;
      next[winnerSeat] += perOpponent;
    }
  } else {
    const amount = ruleConfig.RULE_HONBA_RON * honba;
    next[winnerSeat] += amount;
    next[discarderSeat] -= amount;
  }

  return next;
}

// spec section 10: ノーテン罰符 — a fixed pool redistributed from noten
// players to tenpai players at an exhaustive draw. No exchange happens
// if every player (or no player) is tenpai.
export function resolveNotenPayments(tenpaiFlags, ruleConfig) {
  const pool = ruleConfig.RULE_NOTEN_POOL;
  const seatCount = tenpaiFlags.length;
  const tenpaiSeats = tenpaiFlags.flatMap((t, i) => (t ? [i] : []));
  const notenSeats = tenpaiFlags.flatMap((t, i) => (t ? [] : [i]));

  const deltas = Array.from({ length: seatCount }, () => 0);
  if (tenpaiSeats.length === 0 || notenSeats.length === 0) return deltas;

  const gainEach = pool / tenpaiSeats.length;
  const payEach = pool / notenSeats.length;
  for (const s of tenpaiSeats) deltas[s] += gainEach;
  for (const s of notenSeats) deltas[s] -= payEach;
  return deltas;
}
