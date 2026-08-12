// YakuEngine: Phase 1 yaku detection (spec sections 14-19, subset).
//
// Implements the basic 1-han list plus chiitoitsu (2-han, listed under
// section 19 but simple enough to include alongside the Phase 1 basics).
// Multi-han "special" yaku (ittsuu, toitoi, sanankou, honitsu/chinitsu,
// chanta, yakuman, ...) and the seasonal/Alice/Shuba systems are Phase
// 2-5 per the roadmap (spec section 62) and are intentionally not
// implemented here; ScoreEngine treats an empty yaku list as "no win".

import { decomposeStandardHand, isChiitoitsu } from '../hand/HandParser.js';
import { isSimple } from '../tiles/Tiles.js';

const YAKUHAI_HONOR_RANKS = new Set([5, 6, 7]); // 白發中 — north (4) never counts (spec section 18).

function meldTiles(meld) {
  if (meld.type === 'sequence') {
    return [0, 1, 2].map((i) => ({ suit: meld.suit, rank: meld.rank + i }));
  }
  const copies = meld.type === 'kan' ? 4 : 3;
  return Array.from({ length: copies }, () => ({ suit: meld.suit, rank: meld.rank }));
}

function allHandTiles(decomposition, calledMelds) {
  const fromDecomp = [
    ...decomposition.melds.flatMap(meldTiles),
    { suit: decomposition.pair.suit, rank: decomposition.pair.rank },
    { suit: decomposition.pair.suit, rank: decomposition.pair.rank },
  ];
  const fromCalled = calledMelds.flatMap(meldTiles);
  return [...fromDecomp, ...fromCalled];
}

function isYakuhaiSet(meld) {
  return (meld.type === 'triplet' || meld.type === 'kan') && meld.suit === 'z';
}

function yakuhaiHan(meld, { roundWind, seatWind }) {
  if (!isYakuhaiSet(meld)) return 0;
  if (meld.rank === 4) return 0; // north is never a yakuhai (spec section 18)
  if (YAKUHAI_HONOR_RANKS.has(meld.rank)) return 1;
  let han = 0;
  if (meld.rank === roundWind) han += 1;
  if (meld.rank === seatWind) han += 1;
  return han;
}

function isTanyaoHand(allTiles) {
  return allTiles.every(isSimple);
}

function pinfuEligible(decomposition, calledMelds, ctx) {
  if (calledMelds.length > 0 || !ctx.isMenzen) return false;
  if (decomposition.melds.some((m) => m.type !== 'sequence')) return false;
  const { pair } = decomposition;
  if (pair.suit === 'z' && (YAKUHAI_HONOR_RANKS.has(pair.rank) || pair.rank === ctx.roundWind || pair.rank === ctx.seatWind)) {
    return false;
  }
  return ctx.waitIsTwoSided === true;
}

function iipeikouCount(decomposition) {
  const seqKeys = decomposition.melds
    .filter((m) => m.type === 'sequence')
    .map((m) => `${m.suit}${m.rank}`);
  const counts = new Map();
  for (const k of seqKeys) counts.set(k, (counts.get(k) ?? 0) + 1);
  let pairs = 0;
  for (const n of counts.values()) pairs += Math.floor(n / 2);
  return pairs;
}

// ctx: {
//   concealedTiles, calledMelds, winTile, isTsumo, isMenzen,
//   roundWind, seatWind, riichi: { active, ippatsu, open, furo },
//   isHaitei, isHoutei, isChankan, isRinshan, waitIsTwoSided,
// }
export function evaluateYaku(ctx, _ruleConfig) {
  const candidates = [];

  if (ctx.concealedTiles.length === 14 - ctx.calledMelds.length * 3 && isChiitoitsu([...ctx.concealedTiles])) {
    candidates.push(evaluateForChiitoitsu(ctx));
  }

  const decompositions = decomposeStandardHand(ctx.concealedTiles);
  const requiredMelds = 4 - ctx.calledMelds.length;
  for (const d of decompositions) {
    if (d.melds.length !== requiredMelds) continue;
    candidates.push(evaluateForStandard(d, ctx));
  }

  if (candidates.length === 0) return { yakuList: [], han: 0, hasYaku: false };

  candidates.sort((a, b) => b.han - a.han);
  return candidates[0];
}

function evaluateForChiitoitsu(ctx) {
  const yakuList = [{ name: '七対子', han: 2 }];
  pushCommonYaku(yakuList, ctx, { isMenzenOverride: true });
  const han = yakuList.reduce((s, y) => s + y.han, 0);
  return { yakuList, han, hasYaku: yakuList.length > 0 };
}

function evaluateForStandard(decomposition, ctx) {
  const allTiles = allHandTiles(decomposition, ctx.calledMelds);
  const yakuList = [];

  if (ctx.isMenzen) {
    const iipeikou = iipeikouCount(decomposition);
    if (iipeikou >= 1) yakuList.push({ name: '一盃口', han: 1 });
  }

  if (isTanyaoHand(allTiles)) yakuList.push({ name: 'タンヤオ', han: 1 });

  if (pinfuEligible(decomposition, ctx.calledMelds, ctx)) {
    yakuList.push({ name: '平和', han: 1 });
  }

  const allSets = [...decomposition.melds, ...ctx.calledMelds];
  let yakuhaiHanTotal = 0;
  for (const m of allSets) yakuhaiHanTotal += yakuhaiHan(m, ctx);
  if (yakuhaiHanTotal > 0) yakuList.push({ name: '役牌', han: yakuhaiHanTotal });

  pushCommonYaku(yakuList, ctx, {});

  const han = yakuList.reduce((s, y) => s + y.han, 0);
  return { yakuList, han, hasYaku: yakuList.length > 0, decomposition };
}

function pushCommonYaku(yakuList, ctx, { isMenzenOverride } = {}) {
  const menzen = isMenzenOverride ?? ctx.isMenzen;
  const riichi = ctx.riichi ?? {};

  if (riichi.open) {
    yakuList.push({ name: 'オープンリーチ', han: ctx.ruleConfig?.RULE_OPEN_RIICHI_HAN ?? 2 });
  } else if (riichi.furo) {
    // 副露リーチ is 0 han by itself; legality (needs another confirmed
    // yaku, or must be open) is enforced by the turn engine.
  } else if (riichi.active && menzen) {
    yakuList.push({ name: '立直', han: 1 });
  }

  if (riichi.ippatsu) yakuList.push({ name: '一発', han: 1 });
  if (ctx.isTsumo && menzen) yakuList.push({ name: '門前自摸', han: 1 });
  if (ctx.isTsumo && ctx.isHaitei) yakuList.push({ name: '海底摸月', han: 1 });
  if (!ctx.isTsumo && ctx.isHoutei) yakuList.push({ name: '河底撈魚', han: 1 });
  if (ctx.isChankan) yakuList.push({ name: '槍槓', han: 1 });
  if (ctx.isTsumo && ctx.isRinshan) yakuList.push({ name: '嶺上開花', han: 1 });
}

// A 副露リーチ (furo riichi) declaration is only legal without going
// open if the hand already has a confirmed yaku from its melds (spec
// section 15). `otherHan` excludes the furo-riichi placeholder itself.
export function requiresOpenForFuroRiichi(otherHan) {
  return otherHan <= 0;
}
