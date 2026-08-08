/// Wire-level intents a client can submit for a match (STEP4「通信設計」).
/// The server never trusts a client's claimed *outcome* — only its claimed
/// *intent* — and re-derives what actually happens by applying it to the
/// authoritative [GameState] (see `action_validator.dart`).
library;

import 'package:mahjong_engine/mahjong_engine.dart';

sealed class MatchAction {
  final int playerIndex;
  const MatchAction(this.playerIndex);
}

class DrawAction extends MatchAction {
  const DrawAction(super.playerIndex);
}

class DiscardAction extends MatchAction {
  final Tile tile;
  const DiscardAction(super.playerIndex, this.tile);
}

class RiichiDiscardAction extends MatchAction {
  final Tile tile;
  const RiichiDiscardAction(super.playerIndex, this.tile);
}

class TsumoAction extends MatchAction {
  const TsumoAction(super.playerIndex);
}

class RonAction extends MatchAction {
  const RonAction(super.playerIndex);
}

class PonAction extends MatchAction {
  const PonAction(super.playerIndex);
}

class AnkanAction extends MatchAction {
  final Tile tile;
  const AnkanAction(super.playerIndex, this.tile);
}

class DaiminkanAction extends MatchAction {
  const DaiminkanAction(super.playerIndex);
}

class ShouminkanAction extends MatchAction {
  final Tile tile;
  const ShouminkanAction(super.playerIndex, this.tile);
}
