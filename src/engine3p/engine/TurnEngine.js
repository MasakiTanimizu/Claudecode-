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

export function declareRiichi(game, seat, { open = false } = {}) {
  const player = game.players[seat];
  if (!isMenzenNow(player) && !open) {
    throw new Error('Riichi requires a menzen hand unless declared as furo riichi');
  }
  const cost = game.ruleConfig.RULE_RIICHI_STICK;
  if (player.score < cost) throw new Error('Not enough points to declare riichi');

  player.score -= cost;
  game.round.riichiSticks += 1;
  player.riichi.active = true;
  player.riichi.open = open && !isMenzenNow(player);
  player.riichi.furo = !isMenzenNow(player) && !player.riichi.open;
  player.riichi.ippatsu = true;
  player.riichi.declaredAtTurn = game.round.turn;
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

export function checkTsumoWin(game, seat) {
  const player = game.players[seat];
  return evaluateWin(game, seat, {
    concealedTiles: player.hand,
    isTsumo: true,
    winTile: player.hand[player.hand.length - 1],
  });
}

export function checkRonWin(game, seat, discarderSeat, tile) {
  const player = game.players[seat];
  if (player.furiten) return { canWin: false, reason: 'furiten' };
  const concealedTiles = [...player.hand, tile];
  return evaluateWin(game, seat, { concealedTiles, isTsumo: false, winTile: tile, discarderSeat });
}

function evaluateWin(game, seat, { concealedTiles, isTsumo, winTile, discarderSeat }) {
  const player = game.players[seat];
  const meldCount = player.melds.length;
  if (!isComplete(concealedTiles, meldCount)) return { canWin: false, reason: 'not_complete' };

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
    isChankan: false,
    isRinshan: false,
    waitIsTwoSided: true,
    ruleConfig: game.ruleConfig,
  };

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
  const { seat, ctx, yakuResult, isDealer, isTsumo, discarderSeat } = winCheck;
  const player = game.players[seat];
  const decomposition = yakuResult.decomposition ?? { melds: [], pair: null };
  const isChiitoitsuWin = yakuResult.yakuList.some((y) => y.name === '七対子');

  const activeSeasons = getActiveSeasons(player.flowerTiles, game.round.doraIndicators, game.round.uraDoraIndicators);

  const doraResult = computeDoraHan({
    handTiles: ctx.concealedTiles,
    doraIndicators: game.round.doraIndicators,
    uraDoraIndicators: game.round.uraDoraIndicators,
    riichiActive: player.riichi.active,
    kitaCount: player.kitaTiles.length,
  });
  const autumnBonusHan = computeAutumnBonusHan(ctx.concealedTiles, activeSeasons);

  const fu = computeFu(decomposition, ctx.calledMelds, {
    ...ctx,
    hasPinfu: yakuResult.yakuList.some((y) => y.name === '平和'),
    isChiitoitsu: isChiitoitsuWin,
  });
  const han = yakuResult.han + doraResult.total + autumnBonusHan;
  const base = applySummerRankUp(computeBasePoints(fu, han), activeSeasons);

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
  // Riichi sticks on the table go to the winner.
  game.score[seat] += game.round.riichiSticks * game.ruleConfig.RULE_RIICHI_STICK;
  game.round.riichiSticks = 0;

  const chipResult = computeChips({
    handTiles: ctx.concealedTiles,
    isMenzen: ctx.isMenzen,
    riichiActive: player.riichi.active,
    uraDoraIndicators: game.round.uraDoraIndicators,
    ippatsu: player.riichi.ippatsu,
    kitaCount: player.kitaTiles.length,
    isWin: true,
    shubaTier: game.shubariichi?.tier?.[seat] ?? null,
  }, game.ruleConfig);
  game.chip = applyChipDelta(game.chip, [seat === 0 ? chipResult.total : 0, seat === 1 ? chipResult.total : 0, seat === 2 ? chipResult.total : 0]);

  return {
    fu,
    han,
    base,
    scoreDeltas: withHonba,
    chipResult,
    yakuList: yakuResult.yakuList,
    doraResult,
    activeSeasons,
  };
}

export function resolveExhaustiveDraw(game) {
  const tenpaiFlags = game.players.map((p) => isTenpai(p.hand, p.melds.length));
  const deltas = resolveNotenPayments(tenpaiFlags, game.ruleConfig);
  game.score = applyScoreDelta(game.score, deltas);
  return { tenpaiFlags, deltas };
}
