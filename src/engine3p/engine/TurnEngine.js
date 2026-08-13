// TurnEngine: orchestrates a single hand's turn flow — draw, discard,
// calls, kita/hana, riichi, and win resolution — wiring together the
// wall, hand parser, yaku engine, score engine and chip engine.
//
// This module intentionally mutates the `game` object it's given (it is
// meant to sit behind a server-authoritative reducer/socket layer per
// spec section 52, not to be used as a pure state-transition function).
// Call-priority arbitration between simultaneous chi/pon/kan/ron claims
// from multiple players, and full reconnect/replay wiring, are Phase 2/6
// concerns layered on top of these primitives.

import { drawTile as drawFromWall, drawReplacement } from '../wall/Wall.js';
import { isComplete, isTenpai, getWinningTiles } from '../hand/HandParser.js';
import { tileKey, isNorth } from '../tiles/Tiles.js';
import { evaluateYaku } from '../yaku/YakuEngine.js';
import { detectYakuman, usesNorthTile } from '../yaku/Yakuman.js';
import { computeFu, computeBasePoints, computeWinPayments, applyHonba, resolveNotenPayments } from '../scoring/ScoreEngine.js';
import { computeDoraHan } from '../scoring/DoraHan.js';
import { computeSpringChips, getActiveSeasons, computeAutumnBonusHan, applySummerRankUp } from '../scoring/SeasonEffects.js';
import { computeChips } from '../chips/ChipEngine.js';
import { applyScoreDelta, applyChipDelta } from '../state/ScoreState.js';
import { markHakuPotchiIfDrawn } from '../state/WhitePotchiState.js';

export function seatWindOf(seat, dealerSeat) {
  // 0 = East (dealer), 1 = South, 2 = West, rotating from the dealer.
  return ((seat - dealerSeat + 3) % 3) + 1;
}

function isMenzenNow(player) {
  return player.melds.every((m) => m.type === 'kan' && m.concealed);
}

export function drawForTurn(game, seat) {
  const tile = drawFromWall(game.wall);
  if (!tile) return null;
  const player = game.players[seat];
  player.hand.push(tile);
  game.round.turn = seat;

  const isFirstDrawForSeat = !game.round.firstDrawDoneBySeat[seat];
  game.round.firstDrawDoneBySeat[seat] = true;
  game.round.totalDraws += 1;
  game.round.lastDrawWasFirstUninterrupted = isFirstDrawForSeat && !game.round.anyCallMade;

  game.whitePotchi = markHakuPotchiIfDrawn(game.whitePotchi, seat, tile, {
    riichiActive: player.riichi.active,
    riichiEverDeclared: player.riichi.declaredAtTurn !== null,
  });
  return tile;
}

export function discardTile(game, seat, tileId) {
  const player = game.players[seat];
  const idx = player.hand.findIndex((t) => t.id === tileId);
  if (idx === -1) throw new Error(`Tile ${tileId} not in seat ${seat}'s hand`);
  const [tile] = player.hand.splice(idx, 1);
  player.discards.push(tile);

  // Furiten: a player is furiten if any of their own discards would
  // complete their current hand.
  refreshFuriten(game, seat);

  // Closes this player's own ippatsu window; declaring riichi re-opens
  // it below when the riichi discard itself is processed.
  player.riichi.ippatsu = false;

  return tile;
}

export function refreshFuriten(game, seat) {
  const player = game.players[seat];
  const meldCount = player.melds.length;
  const winners = new Set(getWinningTiles(player.hand, meldCount));
  player.furiten = player.discards.some((d) => winners.has(tileKey(d.suit, d.rank)));
}

const SHUBA_TIERS = new Set(['shuba', 'shubazoma', 'shubante']);

// shubaTier declares シュバ/シュバゾーマ/シュバンテ instead of a plain
// リーチ (spec section 36, costs per the user's clarification):
//   通常: 供託1000
//   シュバ/シュバゾーマ: 供託1000 + シバ棒(1回/局のトークン)
//   シュバンテ: 供託に持ち点全て（要スコア > 60000）+ シバ棒
export function declareRiichi(game, seat, { open = false, shubaTier = null } = {}) {
  const player = game.players[seat];
  if (!isMenzenNow(player) && !open) {
    throw new Error('Riichi requires a menzen hand unless declared as furo riichi');
  }

  // Score lives in ScoreState (game.score), not PlayerState — spec
  // section 12/41 keep Score/Chip/RankPoint/Bonus as separate state
  // slices, so this reads/writes the array, never a per-player field.
  if (shubaTier !== null) {
    if (!SHUBA_TIERS.has(shubaTier)) throw new Error(`Unknown shuba tier: ${shubaTier}`);
    if (!game.shubariichi.availableBySeat[seat]) throw new Error('Shuba stick already used this hand');
    if (shubaTier === 'shubante' && game.score[seat] <= game.ruleConfig.RULE_SHUBANTE_MIN_SCORE) {
      throw new Error('Shubante requires more than RULE_SHUBANTE_MIN_SCORE points');
    }
  }

  const cost = shubaTier === 'shubante' ? game.score[seat] : game.ruleConfig.RULE_RIICHI_STICK;
  if (game.score[seat] < cost) throw new Error('Not enough points to declare riichi');

  game.score[seat] -= cost;
  game.round.kyoutakuPoints += cost;
  player.riichi.active = true;
  player.riichi.open = open && !isMenzenNow(player);
  player.riichi.furo = !isMenzenNow(player) && !player.riichi.open;
  player.riichi.ippatsu = true;
  player.riichi.declaredAtTurn = game.round.turn;

  if (shubaTier !== null) {
    game.shubariichi.availableBySeat[seat] = false;
    game.shubariichi.tierBySeat[seat] = shubaTier;
  }
}

function markReplacementPotchi(game, seat, replacement) {
  if (!replacement) return;
  const player = game.players[seat];
  game.whitePotchi = markHakuPotchiIfDrawn(game.whitePotchi, seat, replacement, {
    riichiActive: player.riichi.active,
    riichiEverDeclared: player.riichi.declaredAtTurn !== null,
  });
}

export function declareKita(game, seat, tileId) {
  const player = game.players[seat];
  const idx = player.hand.findIndex((t) => t.id === tileId && isNorth(t));
  if (idx === -1) throw new Error('No north tile to extract');
  const [tile] = player.hand.splice(idx, 1);
  player.kitaTiles.push(tile);
  clearAllIppatsu(game);
  const replacement = drawReplacement(game.wall);
  if (replacement) player.hand.push(replacement);
  markReplacementPotchi(game, seat, replacement);
  return { extracted: tile, replacement };
}

// spec section 29: 春を抜いた瞬間、抜いている季節牌の数だけ祝儀を獲得する。
export function declareFlowerDraw(game, seat, tileId) {
  const player = game.players[seat];
  const idx = player.hand.findIndex((t) => t.id === tileId && t.suit === 'f');
  if (idx === -1) throw new Error('No flower tile to extract');
  const [tile] = player.hand.splice(idx, 1);
  player.flowerTiles.push(tile);
  game.flower.drawnBySeat[seat].push(tile);

  let springChips = 0;
  if (tile.rank === 1 /* 春 */) {
    springChips = computeSpringChips(player.flowerTiles.length);
    const delta = [0, 0, 0];
    delta[seat] = springChips;
    game.chip = applyChipDelta(game.chip, delta);
    // Paid immediately, but if this player later wins with a shuba tier
    // active, resolveWin tops this base amount up to the multiplied one.
    player.hanaChipsThisHand += springChips;
  }

  clearAllIppatsu(game);
  const replacement = drawReplacement(game.wall);
  if (replacement) player.hand.push(replacement);
  markReplacementPotchi(game, seat, replacement);
  return { extracted: tile, replacement, springChips };
}

function clearAllIppatsu(game) {
  for (const p of game.players) p.riichi.ippatsu = false;
}

// Chi is removed from this ruleset entirely (house rule). The check is
// still config-gated (RULE_CHI_ENABLED) rather than deleted outright, in
// keeping with the "everything is a RuleConfig switch" design (spec
// section 58) — flip it back on for a future variant without touching
// call-priority logic. Note man suit could never form a chi anyway
// (only rank 1/9 exist), so this is never reachable for 'm' regardless.
export function canDeclareChi(ruleConfig, calledTile) {
  if (!ruleConfig.RULE_CHI_ENABLED) return false;
  if (calledTile.suit === 'm' || calledTile.suit === 'z' || calledTile.suit === 'f') return false;
  return true;
}

function popLastDiscard(game, discarderSeat, expectedSuit, expectedRank) {
  const discarder = game.players[discarderSeat];
  const last = discarder.discards[discarder.discards.length - 1];
  if (!last || last.suit !== expectedSuit || last.rank !== expectedRank) {
    throw new Error('No matching discard available to call');
  }
  return discarder.discards.pop();
}

function removeHandTiles(player, tileIds) {
  const removed = [];
  for (const id of tileIds) {
    const idx = player.hand.findIndex((t) => t.id === id);
    if (idx === -1) throw new Error(`Tile ${id} not in hand`);
    removed.push(player.hand.splice(idx, 1)[0]);
  }
  return removed;
}

function requireSameTile(tiles, label) {
  const [first] = tiles;
  if (!tiles.every((t) => t.suit === first.suit && t.rank === first.rank)) {
    throw new Error(`${label} tiles must all match`);
  }
  return first;
}

export function declarePon(game, callerSeat, discarderSeat, handTileIds) {
  if (handTileIds.length !== 2) throw new Error('Pon requires exactly 2 hand tiles');
  const caller = game.players[callerSeat];
  const removed = removeHandTiles(caller, handTileIds);
  const { suit, rank } = requireSameTile(removed, 'Pon');
  const called = popLastDiscard(game, discarderSeat, suit, rank);

  caller.melds.push({ type: 'pon', suit, rank, concealed: false, calledFrom: discarderSeat, tiles: [...removed, called] });
  clearAllIppatsu(game);
  game.round.anyCallMade = true;
  game.round.turn = callerSeat;
  refreshFuriten(game, callerSeat);
  return caller.melds[caller.melds.length - 1];
}

// Daiminkan (大明槓): an open kan called directly off a discard.
export function declareDaiminkan(game, callerSeat, discarderSeat, handTileIds) {
  if (handTileIds.length !== 3) throw new Error('Daiminkan requires exactly 3 hand tiles');
  const caller = game.players[callerSeat];
  const removed = removeHandTiles(caller, handTileIds);
  const { suit, rank } = requireSameTile(removed, 'Kan');
  const called = popLastDiscard(game, discarderSeat, suit, rank);

  caller.melds.push({ type: 'kan', suit, rank, concealed: false, calledFrom: discarderSeat, tiles: [...removed, called] });
  clearAllIppatsu(game);
  game.round.anyCallMade = true;
  game.round.turn = callerSeat;
  const replacement = drawReplacement(game.wall);
  if (replacement) caller.hand.push(replacement);
  markReplacementPotchi(game, callerSeat, replacement);
  refreshFuriten(game, callerSeat);
  return { meld: caller.melds[caller.melds.length - 1], replacement };
}

// Ankan (暗槓): a concealed kan declared from 4 tiles already in hand,
// on the player's own turn. Stays concealed for menzen purposes.
export function declareAnkan(game, seat, handTileIds) {
  if (handTileIds.length !== 4) throw new Error('Ankan requires exactly 4 hand tiles');
  const player = game.players[seat];
  const removed = removeHandTiles(player, handTileIds);
  const { suit, rank } = requireSameTile(removed, 'Kan');

  player.melds.push({ type: 'kan', suit, rank, concealed: true, tiles: removed });
  clearAllIppatsu(game);
  game.round.anyCallMade = true;
  const replacement = drawReplacement(game.wall);
  if (replacement) player.hand.push(replacement);
  markReplacementPotchi(game, seat, replacement);
  refreshFuriten(game, seat);
  return { meld: player.melds[player.melds.length - 1], replacement };
}

// Shouminkan (加槓): upgrades an already-called pon into a kan using the
// 4th matching tile drawn later. The added tile can be robbed by ron
// (槍槓, spec section 18) — the driver should offer every other seat a
// checkRonWin(..., { isChankan: true }) chance against `addedTile`
// before treating this kan (and its replacement draw) as final.
export function declareShouminkan(game, seat, tileId) {
  const player = game.players[seat];
  const idx = player.hand.findIndex((t) => t.id === tileId);
  if (idx === -1) throw new Error(`Tile ${tileId} not in seat ${seat}'s hand`);
  const [tile] = player.hand.splice(idx, 1);
  const ponMeld = player.melds.find((m) => m.type === 'pon' && m.suit === tile.suit && m.rank === tile.rank);
  if (!ponMeld) throw new Error('No matching pon to upgrade into a kan');

  ponMeld.type = 'kan';
  ponMeld.tiles.push(tile);
  clearAllIppatsu(game);
  game.round.anyCallMade = true;
  const replacement = drawReplacement(game.wall);
  if (replacement) player.hand.push(replacement);
  markReplacementPotchi(game, seat, replacement);
  refreshFuriten(game, seat);
  return { meld: ponMeld, addedTile: tile, replacement };
}

export function checkTsumoWin(game, seat, { isRinshan = false } = {}) {
  const player = game.players[seat];
  return evaluateWin(game, seat, {
    concealedTiles: player.hand,
    isTsumo: true,
    winTile: player.hand[player.hand.length - 1],
    isFirstUninterruptedDraw: game.round.lastDrawWasFirstUninterrupted,
    isRinshan,
  });
}

// isChankan: this is a robbing-the-kan ron against the tile just added
// by declareShouminkan (spec section 27), not an ordinary discard ron.
export function checkRonWin(game, seat, discarderSeat, tile, { isChankan = false } = {}) {
  const player = game.players[seat];
  if (player.furiten) return { canWin: false, reason: 'furiten' };
  const concealedTiles = [...player.hand, tile];
  return evaluateWin(game, seat, { concealedTiles, isTsumo: false, winTile: tile, discarderSeat, isChankan });
}

function evaluateWin(game, seat, { concealedTiles, isTsumo, winTile, discarderSeat, isFirstUninterruptedDraw = false, isRinshan = false, isChankan = false }) {
  const player = game.players[seat];
  const meldCount = player.melds.length;
  if (!isComplete(concealedTiles, meldCount)) return { canWin: false, reason: 'not_complete' };

  // North can only ever be a hand tile for kokushi/tsuuiisou/shousuushii/
  // daisuushii (spec section 6/18) — reject any other "complete" hand
  // that happens to include it (e.g. a north triplet counted like an
  // ordinary honor triplet by the generic hand decomposition).
  const yakumanCtx = {
    concealedTiles,
    calledMelds: player.melds,
    winTile,
    isTsumo,
    isFirstUninterruptedDraw,
    isDealer: player.isDealer,
  };
  const yakumanResult = detectYakuman(yakumanCtx);
  if (usesNorthTile(concealedTiles, player.melds) && !yakumanResult.northEligible) {
    return { canWin: false, reason: 'invalid_north_usage' };
  }

  const menzen = isMenzenNow(player);
  const seatWind = seatWindOf(seat, game.round.dealerSeat);
  const ctx = {
    concealedTiles,
    calledMelds: player.melds,
    winTile,
    isTsumo,
    isMenzen: menzen,
    roundWind: game.round.roundWind,
    seatWind,
    riichi: player.riichi,
    isHaitei: isTsumo && game.wall.liveWall.length === 0,
    isHoutei: !isTsumo && game.wall.liveWall.length === 0,
    isChankan,
    isRinshan,
    waitIsTwoSided: true,
    ruleConfig: game.ruleConfig,
  };

  if (yakumanResult.isYakuman) {
    return {
      canWin: true,
      isYakuman: true,
      yakumanResult,
      ctx,
      isDealer: player.isDealer,
      seat,
      isTsumo,
      discarderSeat,
    };
  }

  const yakuResult = evaluateYaku(ctx, game.ruleConfig);
  if (player.riichi.furo && !player.riichi.open) {
    const otherHan = yakuResult.han;
    if (otherHan <= 0) return { canWin: false, reason: 'furo_riichi_needs_yaku_or_open' };
  }
  if (!yakuResult.hasYaku) return { canWin: false, reason: 'no_yaku' };

  return {
    canWin: true,
    yakuResult,
    ctx,
    isDealer: player.isDealer,
    seat,
    isTsumo,
    discarderSeat,
  };
}

export function resolveWin(game, winCheck) {
  const { seat, ctx, isDealer, isTsumo, discarderSeat } = winCheck;
  const player = game.players[seat];
  const activeSeasons = getActiveSeasons(player.flowerTiles, game.round.doraIndicators, game.round.uraDoraIndicators);

  const doraResult = computeDoraHan({
    handTiles: ctx.concealedTiles,
    doraIndicators: game.round.doraIndicators,
    uraDoraIndicators: game.round.uraDoraIndicators,
    riichiActive: player.riichi.active,
    kitaCount: player.kitaTiles.length,
  });

  let fu = null;
  let han;
  let base;
  let yakuList;
  let isPureYakuman = false;

  if (winCheck.isYakuman) {
    // This spec's yakuman list (section 22-27) is presented flat with
    // no stacking/double-yakuman rules, so any match uses the same
    // fixed base — see ScoreEngine's mangan-and-up table (han 13 -> 8000).
    isPureYakuman = true;
    han = 13;
    base = applySummerRankUp(8000, activeSeasons, { isYakuman: true });
    yakuList = winCheck.yakumanResult.names.map((name) => ({ name, han: 13 }));
  } else {
    const { yakuResult } = winCheck;
    const decomposition = yakuResult.decomposition ?? { melds: [], pair: null };
    const isChiitoitsuWin = yakuResult.yakuList.some((y) => y.name === '七対子');
    const autumnBonusHan = computeAutumnBonusHan(ctx.concealedTiles, activeSeasons);

    fu = computeFu(decomposition, ctx.calledMelds, {
      ...ctx,
      hasPinfu: yakuResult.yakuList.some((y) => y.name === '平和'),
      isChiitoitsu: isChiitoitsuWin,
    });
    han = yakuResult.han + doraResult.total + autumnBonusHan;
    base = applySummerRankUp(computeBasePoints(fu, han), activeSeasons);
    yakuList = yakuResult.yakuList;
  }
  const isCountedYakuman = !isPureYakuman && han >= 13;

  const { deltas } = computeWinPayments({
    fu,
    han,
    isDealer,
    isTsumo,
    winnerSeat: seat,
    dealerSeat: game.round.dealerSeat,
    discarderSeat,
    forcedBase: base,
  });
  const withHonba = applyHonba(deltas, {
    honba: game.round.honba,
    isTsumo,
    winnerSeat: seat,
    discarderSeat,
    ruleConfig: game.ruleConfig,
  });

  game.score = applyScoreDelta(game.score, withHonba);
  // Everything sitting in the kyoutaku pot (riichi sticks, and any
  // shubante all-in deposits) goes to the winner.
  game.score[seat] += game.round.kyoutakuPoints;
  game.round.kyoutakuPoints = 0;

  const chipResult = computeChips({
    handTiles: ctx.concealedTiles,
    isMenzen: ctx.isMenzen,
    riichiActive: player.riichi.active,
    uraDoraIndicators: game.round.uraDoraIndicators,
    ippatsu: player.riichi.ippatsu,
    kitaCount: player.kitaTiles.length,
    isWin: true,
    shubaTier: game.shubariichi.tierBySeat[seat] ?? null,
    hanaChips: player.hanaChipsThisHand,
    isPureYakuman,
    isCountedYakuman,
    summerActive: activeSeasons.has(2),
  }, game.ruleConfig);
  game.chip = applyChipDelta(game.chip, [seat === 0 ? chipResult.total : 0, seat === 1 ? chipResult.total : 0, seat === 2 ? chipResult.total : 0]);

  return {
    fu,
    han,
    base,
    scoreDeltas: withHonba,
    chipResult,
    yakuList,
    doraResult,
    activeSeasons,
    isYakuman: isPureYakuman,
  };
}

export function resolveExhaustiveDraw(game) {
  const tenpaiFlags = game.players.map((p) => isTenpai(p.hand, p.melds.length));
  const deltas = resolveNotenPayments(tenpaiFlags, game.ruleConfig);
  game.score = applyScoreDelta(game.score, deltas);
  return { tenpaiFlags, deltas };
}
