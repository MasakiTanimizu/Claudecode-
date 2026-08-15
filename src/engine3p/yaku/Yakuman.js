// Yakuman.js: detects the yakuman-tier hands from spec sections 22-27.
// Checked before the regular YakuEngine by TurnEngine.evaluateWin — a
// yakuman hand always uses a fixed base score (see ScoreEngine's
// mangan-and-up table, han 13 -> 8000) regardless of fu/han math, and
// this spec's yakuman list is presented flat with no stacking/double-
// yakuman rules, so detecting any single match is enough.
//
// North (z4) can only ever be a hand tile for kokushi/tsuuiisou/
// shousuushii/daisuushii (spec section 6/18) — every other check here
// operates on hands that structurally can't contain north anyway once
// TurnEngine's north-usage guard runs first.

import { decomposeStandardHand, isKokushi, isChiitoitsu } from '../hand/HandParser.js';
import { isTerminal, isHonor } from '../tiles/Tiles.js';

function meldTiles(meld) {
  if (meld.type === 'sequence') return [0, 1, 2].map((i) => ({ suit: meld.suit, rank: meld.rank + i }));
  const copies = meld.type === 'kan' ? 4 : 3;
  return Array.from({ length: copies }, () => ({ suit: meld.suit, rank: meld.rank }));
}

function allHandTiles(decomposition, calledMelds) {
  return [
    ...decomposition.melds.flatMap(meldTiles),
    { suit: decomposition.pair.suit, rank: decomposition.pair.rank },
    { suit: decomposition.pair.suit, rank: decomposition.pair.rank },
    ...calledMelds.flatMap(meldTiles),
  ];
}

function isTripletLike(m) {
  return m.type === 'triplet' || m.type === 'kan';
}

function hasSet(sets, suit, rank) {
  return sets.some((m) => isTripletLike(m) && m.suit === suit && m.rank === rank);
}

const NORTH_ELIGIBLE = new Set(['kokushi', 'tsuuiisou', 'shousuushii', 'daisuushii']);

function checkSuuankou(decomposition, calledMelds, ctx) {
  if (!calledMelds.every((m) => m.type === 'kan' && m.concealed)) return false;
  const allSets = [...decomposition.melds, ...calledMelds];
  if (allSets.length !== 4 || !allSets.every(isTripletLike)) return false;
  if (ctx.isTsumo) return true;
  // Ron: only valid if the pair (not a triplet) was the wait.
  return ctx.winTile && ctx.winTile.suit === decomposition.pair.suit && ctx.winTile.rank === decomposition.pair.rank;
}

const GREEN_TILES = new Set(['s2', 's3', 's4', 's6', 's8', 'z6']);

function checkRyuuiisou(allTiles) {
  return allTiles.every((t) => GREEN_TILES.has(`${t.suit}${t.rank}`));
}

function checkSuurenkou(allSets) {
  for (const suit of ['p', 's']) {
    for (let rank = 1; rank <= 6; rank++) {
      if ([0, 1, 2, 3].every((i) => hasSet(allSets, suit, rank + i))) return true;
    }
  }
  return false;
}

function checkManzuHonitsu(allTiles) {
  const nonHonorSuits = new Set(allTiles.filter((t) => !isHonor(t)).map((t) => t.suit));
  return nonHonorSuits.size === 1 && nonHonorSuits.has('m');
}

function checkChinitsuChiitoi(concealedTiles, calledMelds) {
  if (calledMelds.length > 0 || !isChiitoitsu(concealedTiles)) return false;
  const suits = new Set(concealedTiles.map((t) => t.suit));
  return suits.size === 1 && (suits.has('p') || suits.has('s'));
}

function checkShapesForDecomposition(decomposition, calledMelds, ctx, names) {
  const allSets = [...decomposition.melds, ...calledMelds];
  const allTiles = allHandTiles(decomposition, calledMelds);

  if (checkSuuankou(decomposition, calledMelds, ctx)) names.add('四暗刻');
  if ([5, 6, 7].every((r) => hasSet(allSets, 'z', r))) names.add('大三元');
  if (allTiles.every(isHonor)) names.add('字一色');

  const windTriplets = [1, 2, 3, 4].filter((r) => hasSet(allSets, 'z', r));
  if (windTriplets.length === 3 && decomposition.pair.suit === 'z' && [1, 2, 3, 4].includes(decomposition.pair.rank) && !windTriplets.includes(decomposition.pair.rank)) {
    names.add('小四喜');
  }
  if (windTriplets.length === 4) names.add('大四喜');

  if (allTiles.every(isTerminal)) names.add('清老頭');
  if (checkRyuuiisou(allTiles)) names.add('緑一色');
  if (calledMelds.filter((m) => m.type === 'kan').length === 4) names.add('四槓子');
  if (checkSuurenkou(allSets)) names.add('四連刻');
  if (checkManzuHonitsu(allTiles)) names.add('萬子の混一色');
}

// ctx: {
//   concealedTiles, calledMelds, winTile, isTsumo,
//   isFirstUninterruptedDraw, isDealer,
// }
export function detectYakuman(ctx) {
  const names = new Set();

  if (ctx.calledMelds.length === 0 && isKokushi(ctx.concealedTiles)) names.add('国士無双');
  if (checkChinitsuChiitoi(ctx.concealedTiles, ctx.calledMelds)) names.add('清一色七対子');

  const requiredMelds = 4 - ctx.calledMelds.length;
  for (const d of decomposeStandardHand(ctx.concealedTiles)) {
    if (d.melds.length !== requiredMelds) continue;
    checkShapesForDecomposition(d, ctx.calledMelds, ctx, names);
  }

  if (ctx.isTsumo && ctx.isFirstUninterruptedDraw) {
    names.add(ctx.isDealer ? '天和' : '地和');
  }

  const northEligible = [...names].some((n) => NORTH_ELIGIBLE.has(nameToKey(n)));
  return { isYakuman: names.size > 0, names: [...names], northEligible };
}

const NAME_TO_KEY = {
  国士無双: 'kokushi',
  字一色: 'tsuuiisou',
  小四喜: 'shousuushii',
  大四喜: 'daisuushii',
};

function nameToKey(name) {
  return NAME_TO_KEY[name] ?? name;
}

export function usesNorthTile(concealedTiles, calledMelds) {
  return concealedTiles.some((t) => t.suit === 'z' && t.rank === 4)
    || calledMelds.some((m) => m.suit === 'z' && m.rank === 4);
}
