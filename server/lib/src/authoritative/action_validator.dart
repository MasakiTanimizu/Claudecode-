/// Applies a client-claimed [MatchAction] to the authoritative [GameState]
/// (STEP4「通信設計」— サーバー権威判定).
///
/// [GameState]'s own mutating methods already reject illegal *moves*
/// (StateError) — wrong phase, tile not in hand, hand not tenpai, and so
/// on — but several of them (draw/discard/riichi/ankan/shouminkan) act on
/// `state.currentPlayerIndex` without asking who's actually calling. That
/// gap is exactly what a malicious or buggy client could exploit: claim to
/// be the current player when they aren't. This module closes it, then
/// turns any GameState rejection into a structured [MatchActionResult]
/// instead of letting the exception reach the RPC layer.
library;

import 'package:mahjong_engine/mahjong_engine.dart';

import 'match_action.dart';

sealed class MatchActionResult {
  const MatchActionResult();
}

class MatchActionAccepted extends MatchActionResult {
  const MatchActionAccepted();
}

class MatchActionRejected extends MatchActionResult {
  final String reason;
  const MatchActionRejected(this.reason);
}

void _requireCurrentPlayer(GameState state, int playerIndex) {
  if (state.currentPlayerIndex != playerIndex) {
    throw StateError(
      'player $playerIndex acted out of turn (current: ${state.currentPlayerIndex})',
    );
  }
}

/// Validates and applies [action] to [state], mutating it on success.
/// [state] is left unchanged on rejection — every [GameState] mutator that
/// can fail validates before mutating anything (see their own StateError
/// guards), so a caught StateError here never leaves a half-applied move.
MatchActionResult applyMatchAction(GameState state, MatchAction action) {
  try {
    switch (action) {
      case DrawAction a:
        _requireCurrentPlayer(state, a.playerIndex);
        state.drawForCurrentPlayer();
      case DiscardAction a:
        _requireCurrentPlayer(state, a.playerIndex);
        state.discard(a.tile);
      case RiichiDiscardAction a:
        _requireCurrentPlayer(state, a.playerIndex);
        state.declareRiichiAndDiscard(a.tile);
      case TsumoAction a:
        _requireCurrentPlayer(state, a.playerIndex);
        state.declareTsumo();
      case AnkanAction a:
        _requireCurrentPlayer(state, a.playerIndex);
        state.declareAnkan(a.tile);
      case ShouminkanAction a:
        _requireCurrentPlayer(state, a.playerIndex);
        state.declareShouminkan(a.tile);
      // Ron/pon/daiminkan are reactions, not turn-bound moves — GameState's
      // own methods already take the reacting player's index explicitly
      // and validate eligibility internally (canDeclareRon/canDeclarePon/
      // canDeclareDaiminkan), so there's no separate identity check here.
      case RonAction a:
        state.declareRon(a.playerIndex);
      case PonAction a:
        state.declarePon(a.playerIndex);
      case DaiminkanAction a:
        state.declareDaiminkan(a.playerIndex);
    }
    return const MatchActionAccepted();
  } on StateError catch (error) {
    return MatchActionRejected(error.message);
  }
}
