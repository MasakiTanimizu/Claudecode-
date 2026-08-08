/// Danger-aware discard selection (STEP8「他家に危険な気配があるかを判定し、
/// あれば安全牌（現物・スジ・壁）を優先、なければ牌効率...を優先して打牌を選ぶ」).
///
/// Layered on top of `heuristic_discard.dart`'s tile-efficiency baseline:
/// when a safe tile exists, prefer it (genbutsu over mere suji, then tile
/// efficiency as the tiebreak among equally-safe options); when none does,
/// push by falling back to pure tile efficiency. Difficulty-tier folding
/// (e.g. 初級 mostly ignoring danger) is left to the caller, which already
/// has to decide *whether* to call this function at all versus the plain
/// [chooseDiscard] — see docs/design/08「防御」difficulty table.
library;

import '../core/hand.dart';
import '../core/tile.dart';
import '../engine/overall_shanten.dart';
import 'danger.dart';
import 'heuristic_discard.dart';
import 'ukeire.dart';

List<Tile> _withoutOne(List<Tile> tiles, Tile toRemove) {
  final copy = List<Tile>.of(tiles);
  copy.remove(toRemove);
  return copy;
}

/// Picks a discard from [hand], preferring a tile that's safe against
/// [riichiOpponentDiscards] (STEP8「安全牌（現物・スジ・壁）を優先」— 壁 isn't
/// covered, see danger.dart's scope note). Falls back to pure tile
/// efficiency ([chooseDiscard]) when no safe tile is available (pushing) or
/// when [riichiOpponentDiscards] is empty (no one to defend against).
Tile chooseDiscardAgainstRiichi(Hand hand, {required List<Tile> riichiOpponentDiscards}) {
  if (riichiOpponentDiscards.isEmpty) {
    return chooseDiscard(hand);
  }

  final candidateTiles = <Tile>{
    for (final tile in hand.concealedTiles)
      if (tile is! KitaTile) tile,
  };
  if (candidateTiles.isEmpty) {
    throw StateError('no legal discard candidates: every concealed tile is 北');
  }

  final safeTiles = candidateTiles.where((t) => isLikelySafe(t, riichiOpponentDiscards)).toSet();
  final pool = safeTiles.isNotEmpty ? safeTiles : candidateTiles;

  final scored = pool.map((tile) {
    final resulting = Hand(
      concealedTiles: _withoutOne(hand.concealedTiles, tile),
      melds: hand.melds,
    );
    return (
      tile: tile,
      isGenbutsu: isGenbutsu(tile, riichiOpponentDiscards),
      shanten: overallShanten(resulting),
      ukeireCount: ukeireKinds(resulting).length,
    );
  }).toList();

  scored.sort((a, b) {
    if (safeTiles.isNotEmpty && a.isGenbutsu != b.isGenbutsu) {
      return a.isGenbutsu ? -1 : 1;
    }
    if (a.shanten != b.shanten) return a.shanten.compareTo(b.shanten);
    return b.ukeireCount.compareTo(a.ukeireCount);
  });

  return scored.first.tile;
}
