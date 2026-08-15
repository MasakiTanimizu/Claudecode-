// YakuEngine: yaku detection (spec sections 14-21, 27).
//
// Covers the 1-han basics, chiitoitsu, and the section 19-21/27 regular
// yaku list (ittsuu, chanta/junchan with the doubling rule, toitoi,
// sanankou, sanshoku doukou, sankantsu, shousangen, sanrenkou, sanfon,
// niipeikou, honitsu, chinitsu). Yakuman (section 22-27's yakuman-tier
// items) is handled by Yakuman.js and checked before this module by the
// turn engine — see TurnEngine.evaluateWin. Alice/Shuba/kinsei are
// still later-phase systems and not implemented here; ScoreEngine
// treats an empty yaku list as "no win".

import { decomposeStandardHand, isChiitoitsu } from '../hand/HandParser.js';
import { isSimple, isTerminalOrHonor, isHonor } from '../tiles/Tiles.js';

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

function isTripletLike(m) {
  return m.type === 'triplet' || m.type === 'kan';
}

function hasSet(sets, suit, rank) {
  return sets.some((m) => isTripletLike(m) && m.suit === suit && m.rank === rank);
}

// spec section 19: 一気通貫 — 123/456/789 of the same suit. Pin/sou only;
// man can never form a sequence (only rank 1/9 exist).
function ittsuuHan(allSets, isMenzen) {
  for (const suit of ['p', 's']) {
    const has = (rank) => allSets.some((m) => m.type === 'sequence' && m.suit === suit && m.rank === rank);
    if (has(1) && has(4) && has(7)) return isMenzen ? 2 : 1;
  }
  return 0;
}

// spec sections 20-21: 混全帯么九(chanta)/純全帯么九(junchan), with the
// chanta-family 2x doubling rule applied afterward by the caller.
// Every set (including the pair) must touch a terminal-or-honor tile;
// junchan additionally forbids any honor tile.
function chantaTier(decomposition, calledMelds) {
  const allSets = [...decomposition.melds, ...calledMelds];
  const setTouchesTerminal = (m) => {
    if (m.type === 'sequence') return m.rank === 1 || m.rank === 7;
    return isTerminalOrHonor({ suit: m.suit, rank: m.rank });
  };
  if (!allSets.every(setTouchesTerminal)) return null;
  if (!isTerminalOrHonor(decomposition.pair)) return null;

  const anyHonor = allSets.some((m) => m.suit === 'z') || isHonor(decomposition.pair);
  return anyHonor ? 'chanta' : 'junchan';
}

function toitoiHan(decomposition) {
  return decomposition.melds.every(isTripletLike) ? 2 : 0;
}

// Ron-completing a triplet counts it as open (minko), same convention
// as ScoreEngine's fu calculation — it does not count toward sanankou.
function isAnkou(meld, ctx) {
  if (meld.type !== 'triplet' && meld.type !== 'kan') return false;
  const containsWinTile = ctx.winTile && ctx.winTile.suit === meld.suit && ctx.winTile.rank === meld.rank;
  if (containsWinTile && !ctx.isTsumo) return false;
  return true;
}

function sanankouHan(decomposition, calledMelds, ctx) {
  const concealedAnkou = decomposition.melds.filter((m) => isAnkou(m, ctx)).length;
  const calledAnkan = calledMelds.filter((m) => m.type === 'kan' && m.concealed).length;
  return (concealedAnkou + calledAnkan) >= 3 ? 2 : 0;
}

// spec section 19: 三色同刻 — since man only has rank 1/9, this can only
// ever be 111 or 999 across man/pin/sou.
function sanshokuDoukouHan(allSets) {
  for (const rank of [1, 9]) {
    if (hasSet(allSets, 'm', rank) && hasSet(allSets, 'p', rank) && hasSet(allSets, 's', rank)) return 2;
  }
  return 0;
}

function sankantsuHan(calledMelds) {
  return calledMelds.filter((m) => m.type === 'kan').length >= 3 ? 2 : 0;
}

// spec section 19: 小三元2翻＋役牌分を加算 — the flat 2han is additive on
// top of whatever 役牌 han the two dragon triplets already contribute.
function shousangenHan(allSets, decomposition) {
  const dragonRanks = [5, 6, 7];
  const triplets = dragonRanks.filter((r) => hasSet(allSets, 'z', r));
  const pairIsDragon = decomposition.pair.suit === 'z' && dragonRanks.includes(decomposition.pair.rank);
  return triplets.length === 2 && pairIsDragon ? 2 : 0;
}

// spec section 27: 三連刻 — 3 triplets of consecutive rank, same suit.
function sanrenkouHan(allSets) {
  for (const suit of ['p', 's']) {
    for (let rank = 1; rank <= 7; rank++) {
      if (hasSet(allSets, suit, rank) && hasSet(allSets, suit, rank + 1) && hasSet(allSets, suit, rank + 2)) return 2;
    }
  }
  return 0;
}

// spec section 27: 三風 — north can never be a hand tile outside
// kokushi/tsuuiisou/shousuushii/daisuushii (section 18), so the only
// three wind tiles that can ever form triplets here are East/South/West.
function sanfonHan(allSets) {
  return [1, 2, 3].every((r) => hasSet(allSets, 'z', r)) ? 2 : 0;
}

function suitOf(tile) {
  return tile.suit;
}

// spec section 20: 混一色(honitsu)/清一色(chinitsu) — one numbered suit,
// optionally mixed with honors for honitsu.
function honitsuOrChinitsuTier(allTiles) {
  const suits = new Set(allTiles.filter((t) => !isHonor(t)).map(suitOf));
  if (suits.size !== 1) return null;
  const hasHonorTile = allTiles.some(isHonor);
  return hasHonorTile ? 'honitsu' : 'chinitsu';
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
  const allSets = [...decomposition.melds, ...ctx.calledMelds];
  const yakuList = [];

  if (ctx.isMenzen) {
    const iipeikou = iipeikouCount(decomposition);
    if (iipeikou >= 2) {
      yakuList.push({ name: '二盃口', han: 3 }); // replaces 一盃口, not additive
    } else if (iipeikou === 1) {
      yakuList.push({ name: '一盃口', han: 1 });
    }
  }

  if (isTanyaoHand(allTiles)) yakuList.push({ name: 'タンヤオ', han: 1 });

  if (pinfuEligible(decomposition, ctx.calledMelds, ctx)) {
    yakuList.push({ name: '平和', han: 1 });
  }

  let yakuhaiHanTotal = 0;
  for (const m of allSets) yakuhaiHanTotal += yakuhaiHan(m, ctx);
  if (yakuhaiHanTotal > 0) yakuList.push({ name: '役牌', han: yakuhaiHanTotal });

  const ittsuu = ittsuuHan(allSets, ctx.isMenzen);
  if (ittsuu > 0) yakuList.push({ name: '一気通貫', han: ittsuu });

  const chantaTierResult = chantaTier(decomposition, ctx.calledMelds);
  if (chantaTierResult) {
    const base = chantaTierResult === 'junchan' ? (ctx.isMenzen ? 3 : 2) : (ctx.isMenzen ? 2 : 1);
    const doubled = base * 2; // spec section 21: チャンタ系2倍
    yakuList.push({ name: chantaTierResult === 'junchan' ? '純全帯么九' : '混全帯么九', han: doubled });
  }

  const toitoi = toitoiHan(decomposition);
  if (toitoi > 0) yakuList.push({ name: '対々和', han: toitoi });

  const sanankou = sanankouHan(decomposition, ctx.calledMelds, ctx);
  if (sanankou > 0) yakuList.push({ name: '三暗刻', han: sanankou });

  const sanshokuDoukou = sanshokuDoukouHan(allSets);
  if (sanshokuDoukou > 0) yakuList.push({ name: '三色同刻', han: sanshokuDoukou });

  const sankantsu = sankantsuHan(ctx.calledMelds);
  if (sankantsu > 0) yakuList.push({ name: '三槓子', han: sankantsu });

  const shousangen = shousangenHan(allSets, decomposition);
  if (shousangen > 0) yakuList.push({ name: '小三元', han: shousangen });

  const sanrenkou = sanrenkouHan(allSets);
  if (sanrenkou > 0) yakuList.push({ name: '三連刻', han: sanrenkou });

  const sanfon = sanfonHan(allSets);
  if (sanfon > 0) yakuList.push({ name: '三風', han: sanfon });

  const suitTier = honitsuOrChinitsuTier(allTiles);
  if (suitTier === 'honitsu') {
    yakuList.push({ name: '混一色', han: ctx.isMenzen ? 3 : 2 });
  } else if (suitTier === 'chinitsu') {
    yakuList.push({ name: '清一色', han: ctx.isMenzen ? 6 : 5 });
  }

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
