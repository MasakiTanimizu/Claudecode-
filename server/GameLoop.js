// GameLoop: orchestrates one hand of 1-human-vs-2-CPU sanma using the
// existing src/engine3p/ primitives (docs/UNITY_INTEGRATION.md's
// protocol). This module is transport-agnostic — it knows nothing about
// WebSocket; server/index.js is the thin adapter that turns incoming
// client messages into calls on a GameLoop instance and forwards the
// `onEvent` callback's payloads back out as frames.
//
// CPU behaviour is intentionally simple (matches the "not yet wired"
// notes in docs/UNITY_INTEGRATION.md): no pon/kan calls, always tsumo
// when available, always ron when available, riichi as soon as menzen
// tenpai is reached, and every north/flower tile is auto-extracted the
// moment it's drawn. This is enough to play a full hand end-to-end; a
// smarter CPU (call decisions, hold-north-for-kokushi judgement, etc.)
// is later-phase work layered on top without changing this loop's shape.

import { createGameState } from '../src/engine3p/state/GameState.js';
import { isNorth } from '../src/engine3p/tiles/Tiles.js';
import { isTenpai } from '../src/engine3p/hand/HandParser.js';
import { isExhausted } from '../src/engine3p/wall/Wall.js';
import {
  seatWindOf, drawForTurn, discardTile, declareRiichi, declareKita, declareFlowerDraw,
  checkTsumoWin, checkRonWin, resolveWin, resolveExhaustiveDraw,
} from '../src/engine3p/engine/TurnEngine.js';
import { isMenzen as isMenzenPlayer } from '../src/engine3p/state/PlayerState.js';
import { chooseDiscard } from '../src/engine3p/ai/DiscardAI.js';
import { DEFAULT_AI_WEIGHTS } from '../src/engine3p/ai/AIWeights.js';

export const HUMAN_SEAT = 0;

export class GameLoop {
  constructor({ game, ruleConfig, weights = DEFAULT_AI_WEIGHTS, humanSeat = HUMAN_SEAT, onEvent = () => {} } = {}) {
    this.game = game ?? createGameState(ruleConfig ? { ruleConfig } : {});
    this.weights = weights;
    this.humanSeat = humanSeat;
    this.onEvent = onEvent;
    this.phase = 'not_started'; // not_started | in_progress | awaiting_human_action | awaiting_human_ron | hand_over
    this.pendingRon = null; // { discarderSeat, tile, cpuSeats }
  }

  start() {
    this.phase = 'in_progress';
    this._emitState();
    this._processSeat(this.game.round.dealerSeat);
  }

  // ---- human-facing actions (called from the WebSocket adapter) ----

  humanTsumo() {
    if (this.phase !== 'awaiting_human_action') return this._emitError('Not your turn to tsumo');
    const check = checkTsumoWin(this.game, this.humanSeat);
    if (!check.canWin) return this._emitError('No tsumo available');
    this._finishTsumo(this.humanSeat, check);
  }

  humanKita(tileId) {
    if (this.phase !== 'awaiting_human_action') return this._emitError('Not your turn');
    try {
      declareKita(this.game, this.humanSeat, tileId);
      this._emitState();
    } catch (err) {
      this._emitError(err.message);
    }
  }

  humanHana(tileId) {
    if (this.phase !== 'awaiting_human_action') return this._emitError('Not your turn');
    try {
      declareFlowerDraw(this.game, this.humanSeat, tileId);
      this._emitState();
    } catch (err) {
      this._emitError(err.message);
    }
  }

  humanRiichi({ open = false, shubaTier = null } = {}) {
    if (this.phase !== 'awaiting_human_action') return this._emitError('Not your turn');
    try {
      declareRiichi(this.game, this.humanSeat, { open, shubaTier });
      this._emitState();
    } catch (err) {
      this._emitError(err.message);
    }
  }

  humanDiscard(tileId) {
    if (this.phase !== 'awaiting_human_action') return this._emitError('Not your turn');
    try {
      discardTile(this.game, this.humanSeat, tileId);
    } catch (err) {
      return this._emitError(err.message);
    }
    this._emitState();
    this.phase = 'in_progress';
    this._afterDiscard(this.humanSeat);
  }

  humanRon() {
    if (this.phase !== 'awaiting_human_ron') return this._emitError('No ron available');
    this._resolvePendingRon(true);
  }

  humanPass() {
    if (this.phase !== 'awaiting_human_ron') return this._emitError('No ron available');
    this._resolvePendingRon(false);
  }

  // ---- turn loop ----

  _processSeat(seat) {
    if (seat === this.humanSeat) return this._startHumanTurn(seat);
    return this._cpuTurn(seat);
  }

  _startHumanTurn(seat) {
    const drawn = drawForTurn(this.game, seat);
    if (!drawn) return this._resolveExhaustiveDraw();
    this.phase = 'awaiting_human_action';
    this._emitState();
  }

  _cpuTurn(seat) {
    const drawn = drawForTurn(this.game, seat);
    if (!drawn) return this._resolveExhaustiveDraw();

    const tsumo = checkTsumoWin(this.game, seat);
    if (tsumo.canWin) return this._finishTsumo(seat, tsumo);

    const rinshanTsumo = this._cpuAutoExtract(seat);
    if (rinshanTsumo) return this._finishTsumo(seat, rinshanTsumo);

    if (this._cpuShouldRiichi(seat)) declareRiichi(this.game, seat, {});

    const tileId = this._cpuChooseDiscard(seat);
    discardTile(this.game, seat, tileId);
    this._emitState();
    return this._afterDiscard(seat);
  }

  // Extracts every north/flower tile the CPU is holding, one at a time
  // (each extraction draws a replacement that might itself be another
  // north/flower tile, or the tile that completes rinshan kaihou).
  // Returns a winCheck if a replacement draw completed the hand, else null.
  _cpuAutoExtract(seat) {
    const player = this.game.players[seat];
    for (;;) {
      const north = player.hand.find((t) => isNorth(t));
      if (north) {
        declareKita(this.game, seat, north.id);
      } else {
        const flower = player.hand.find((t) => t.suit === 'f');
        if (!flower) return null;
        declareFlowerDraw(this.game, seat, flower.id);
      }
      const rinshanTsumo = checkTsumoWin(this.game, seat, { isRinshan: true });
      if (rinshanTsumo.canWin) return rinshanTsumo;
    }
  }

  _cpuShouldRiichi(seat) {
    const player = this.game.players[seat];
    if (player.riichi.active) return false;
    if (!isMenzenPlayer(player)) return false;
    if (this.game.score[seat] < this.game.ruleConfig.RULE_RIICHI_STICK) return false;
    return isTenpai(player.hand, player.melds.length);
  }

  // Picks a discard via the shanten/dora-driven heuristic evaluator
  // (ai/DiscardAI.js). When the CPU just declared riichi this doesn't
  // guarantee the discard keeps the hand tenpai — the evaluator favors
  // it because a tenpai (shanten 0) hand already scores highest, but
  // this is a heuristic CPU tier, not a solved one.
  _cpuChooseDiscard(seat) {
    const player = this.game.players[seat];
    const opponentsDiscards = this.game.players.filter((p) => p.seat !== seat).map((p) => p.discards);
    const ctx = {
      hand: player.hand,
      meldCount: player.melds.length,
      opponentsDiscards,
      doraIndicators: this.game.round.doraIndicators,
      uraDoraIndicators: this.game.round.uraDoraIndicators,
      riichiActive: player.riichi.active,
      kitaCount: player.kitaTiles.length,
      roundWind: this.game.round.roundWind,
      seatWind: seatWindOf(seat, this.game.round.dealerSeat),
      isMenzen: isMenzenPlayer(player),
    };
    return chooseDiscard(ctx, this.weights).tileId;
  }

  _afterDiscard(discarderSeat) {
    const discarder = this.game.players[discarderSeat];
    const tile = discarder.discards[discarder.discards.length - 1];
    const otherSeats = [0, 1, 2].filter((s) => s !== discarderSeat);
    const ronEligible = otherSeats.filter((s) => checkRonWin(this.game, s, discarderSeat, tile).canWin);

    if (ronEligible.length === 0) return this._advanceToNextTurn(discarderSeat);

    if (ronEligible.includes(this.humanSeat)) {
      this.pendingRon = { discarderSeat, tile, cpuSeats: ronEligible.filter((s) => s !== this.humanSeat) };
      this.phase = 'awaiting_human_ron';
      this.onEvent({ type: 'callOpportunity', discardedTile: tile, fromSeat: discarderSeat, options: ['ron', 'pass'] });
      return;
    }

    return this._resolveRonSeats(discarderSeat, tile, ronEligible);
  }

  _resolvePendingRon(humanChose) {
    const { discarderSeat, tile, cpuSeats } = this.pendingRon;
    this.pendingRon = null;
    const seats = humanChose ? [...cpuSeats, this.humanSeat] : [...cpuSeats];
    if (seats.length === 0) {
      this.phase = 'in_progress';
      return this._advanceToNextTurn(discarderSeat);
    }
    return this._resolveRonSeats(discarderSeat, tile, seats);
  }

  // Multi-ron: each winning seat settles independently against the
  // discarder (real ダブロン/トリプルロン pays every winner separately),
  // so this just calls resolveWin once per winning seat in turn.
  _resolveRonSeats(discarderSeat, tile, seats) {
    const results = seats.map((seat) => {
      const winCheck = checkRonWin(this.game, seat, discarderSeat, tile);
      return { seat, ...resolveWin(this.game, winCheck) };
    });
    this._emitHandResult({ winners: seats, isTsumo: false, discarderSeat, results });
  }

  _finishTsumo(seat, winCheck) {
    const result = resolveWin(this.game, winCheck);
    this._emitHandResult({ winner: seat, isTsumo: true, results: [{ seat, ...result }] });
  }

  _advanceToNextTurn(fromSeat) {
    const nextSeat = (fromSeat + 1) % 3;
    if (isExhausted(this.game.wall)) return this._resolveExhaustiveDraw();
    return this._processSeat(nextSeat);
  }

  _resolveExhaustiveDraw() {
    const result = resolveExhaustiveDraw(this.game);
    this._emitHandResult({ isDraw: true, ...result });
  }

  // ---- event emission ----

  _emitState() {
    this.onEvent({ type: 'state', state: this._buildStateView() });
  }

  _emitError(message) {
    this.onEvent({ type: 'error', message });
  }

  _emitHandResult(payload) {
    this.phase = 'hand_over';
    this.onEvent({ type: 'handResult', ...payload });
  }

  _buildStateView() {
    const perspective = this.humanSeat;
    return {
      yourSeat: perspective,
      round: {
        roundWind: this.game.round.roundWind,
        roundNumber: this.game.round.roundNumber,
        honba: this.game.round.honba,
        kyoutakuPoints: this.game.round.kyoutakuPoints,
        dealerSeat: this.game.round.dealerSeat,
        turn: this.game.round.turn,
        doraIndicators: this.game.round.doraIndicators,
      },
      players: this.game.players.map((p) => {
        const base = {
          seat: p.seat,
          isDealer: p.isDealer,
          discards: p.discards,
          melds: p.melds,
          kitaCount: p.kitaTiles.length,
          flowerCount: p.flowerTiles.length,
          riichiActive: p.riichi.active,
          score: this.game.score[p.seat],
          chip: this.game.chip[p.seat],
        };
        return p.seat === perspective ? { ...base, hand: p.hand } : { ...base, handSize: p.hand.length };
      }),
    };
  }
}
