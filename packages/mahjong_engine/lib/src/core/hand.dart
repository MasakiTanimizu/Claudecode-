import 'meld.dart';
import 'tile.dart';

/// A player's tiles: the concealed pile plus any declared melds.
///
/// This is a plain data holder — shanten/yaku/legality all live in `engine/`
/// and `scoring/` (STEP6 layering) and operate *on* a Hand rather than the
/// other way around, so this class stays trivial to construct in tests.
class Hand {
  final List<Tile> concealedTiles;
  final List<Meld> melds;

  Hand({required List<Tile> concealedTiles, List<Meld> melds = const []})
      : concealedTiles = List.unmodifiable(concealedTiles),
        melds = List.unmodifiable(melds);

  /// A hand stays menzen (closed) through ankan — only a call that shows
  /// tiles to other players (chi/pon/daiminkan/shouminkan) breaks it.
  bool get isMenzen => melds.every((m) => !m.isOpen);

  int get kanCount => melds.where((m) => m.kind == MeldKind.kantsu).length;

  int get tileCount =>
      concealedTiles.length + melds.fold(0, (sum, m) => sum + m.tiles.length);

  /// A hand is 13 tiles at rest, +1 per declared kan (the replacement draw
  /// backfills the tile a kan "used up"), and +1 more the instant just after
  /// a draw/call, before that turn's discard.
  bool hasLegalTileCount({required bool justDrew}) {
    final expected = 13 + kanCount + (justDrew ? 1 : 0);
    return tileCount == expected;
  }

  @override
  String toString() {
    final concealed = concealedTiles.map((t) => t.label).join();
    final meldsStr = melds.map((m) => '[${m.tiles.map((t) => t.label).join()}]').join();
    return 'Hand($concealed$meldsStr)';
  }
}
