/// Per-recipient masked game state (STEP9「per-recipient hand masking」):
/// what one specific player is allowed to see of a [GameState] — their own
/// hand in full, everyone else's hand only as a tile count, open melds and
/// discards public to all, per standard mahjong visibility rules.
///
/// Known gap: STEP7/STEP9 say an オープン立直 (open riichi) hand is fully
/// public the instant it's declared, but [GameState] doesn't yet track
/// open-riichi as distinct from a normal riichi (`riichiDeclared` is a
/// single flag either way — see game_state.dart). Until that distinction
/// exists here, [buildPlayerView] can't unmask an open-riichi opponent's
/// hand; it masks every non-viewer hand uniformly regardless of riichi
/// type. Revisit once open-riichi is modeled.
library;

import 'package:mahjong_engine/mahjong_engine.dart';

class PlayerView {
  /// Which player this view was built for.
  final int viewerIndex;

  /// The viewer's own concealed tiles, in full.
  final List<Tile> ownConcealedTiles;

  /// Every player's declared melds, indexed by player — always public
  /// (chi/pon/kan are shown face-up on the table for everyone).
  final List<List<Meld>> melds;

  /// Concealed tile *count* for every player, indexed by player. The
  /// viewer's own slot mirrors [ownConcealedTiles]'s length; every other
  /// slot is a count only, never the tiles themselves.
  final List<int> concealedTileCounts;

  final List<List<Tile>> discardPiles;

  /// Every player's nuku'd hana/kita tiles, indexed by player — always
  /// public, revealed the instant they're nuku'd (see
  /// `GameState.nukiTiles`'s own doc).
  final List<List<Tile>> nukiTiles;

  final List<Tile> doraIndicators;
  final Set<int> riichiPlayers;
  final int currentPlayerIndex;
  final int dealerIndex;
  final TurnPhase phase;
  final RoundResult? result;

  const PlayerView({
    required this.viewerIndex,
    required this.ownConcealedTiles,
    required this.melds,
    required this.concealedTileCounts,
    required this.discardPiles,
    required this.nukiTiles,
    required this.doraIndicators,
    required this.riichiPlayers,
    required this.currentPlayerIndex,
    required this.dealerIndex,
    required this.phase,
    required this.result,
  });
}

/// Builds [viewerIndex]'s masked view of [state].
PlayerView buildPlayerView(GameState state, {required int viewerIndex}) {
  return PlayerView(
    viewerIndex: viewerIndex,
    ownConcealedTiles: state.hands[viewerIndex].concealedTiles,
    melds: [for (final hand in state.hands) hand.melds],
    concealedTileCounts: [for (final hand in state.hands) hand.concealedTiles.length],
    discardPiles: state.discardPiles,
    nukiTiles: state.nukiTiles,
    doraIndicators: state.wall.doraIndicators,
    riichiPlayers: state.riichiDeclared,
    currentPlayerIndex: state.currentPlayerIndex,
    dealerIndex: state.dealerIndex,
    phase: state.phase,
    result: state.result,
  );
}
