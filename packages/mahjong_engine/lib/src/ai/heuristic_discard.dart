/// Heuristic discard selection (STEP8「CPUの1手番の意思決定フロー」実装,
/// step 6: 牌効率を優先して打牌を選ぶ).
///
/// This covers the tile-efficiency baseline only — STEP8's danger-tile
/// evaluation (現物・スジ・壁, pushing vs folding) and difficulty-tier
/// weighting/noise are a separate, later concern layered on top of this.
library;

import '../core/hand.dart';
import '../core/tile.dart';
import '../engine/overall_shanten.dart';
import 'ukeire.dart';

List<Tile> _withoutOne(List<Tile> tiles, Tile toRemove) {
  final copy = List<Tile>.of(tiles);
  copy.remove(toRemove);
  return copy;
}

/// Picks a discard from [hand]'s concealed tiles by tile efficiency:
/// lowest resulting shanten first, then highest resulting ukeire-kind
/// count, then preferring to keep a red/blue-marked tile over a plain one
/// when otherwise tied. 北 is never a candidate — a kept 北 can never be
/// discarded (STEP5「北の扱い改定」).
///
/// Throws [StateError] if every concealed tile is 北 (shouldn't happen in
/// a legal hand, since a 14-tile hand can hold at most a few kept-北).
Tile chooseDiscard(Hand hand) {
  final candidateTiles = <Tile>{
    for (final tile in hand.concealedTiles)
      if (tile is! KitaTile) tile,
  };
  if (candidateTiles.isEmpty) {
    throw StateError('no legal discard candidates: every concealed tile is 北');
  }

  final candidates = candidateTiles.map((tile) {
    final resulting = Hand(
      concealedTiles: _withoutOne(hand.concealedTiles, tile),
      melds: hand.melds,
    );
    return (
      tile: tile,
      shanten: overallShanten(resulting),
      ukeireCount: ukeireKinds(resulting).length,
      discardsMark: tile is NumberTile && tile.mark != TileMark.none,
    );
  }).toList();

  candidates.sort((a, b) {
    if (a.shanten != b.shanten) return a.shanten.compareTo(b.shanten);
    if (a.ukeireCount != b.ukeireCount) return b.ukeireCount.compareTo(a.ukeireCount);
    if (a.discardsMark != b.discardsMark) return a.discardsMark ? 1 : -1;
    return 0;
  });

  return candidates.first.tile;
}
