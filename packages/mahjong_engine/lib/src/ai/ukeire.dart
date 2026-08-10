/// 受け入れ枚数 (ukeire): which tile kinds would improve a hand's shanten if
/// drawn (STEP8「CPU思考アルゴリズム」実装).
///
/// Scoped to *kinds*, not physical tile counts: telling you "5p and 8p help"
/// doesn't require knowing how many of each are still live (in the wall, in
/// other hands, in discards) — that needs visibility this pure hand-shape
/// module doesn't have. A caller with that visibility (the AI's danger/
/// efficiency layer, or a future UI hint feature) can weight these kinds by
/// remaining count itself.
library;

import '../core/hand.dart';
import '../core/tile.dart';
import '../engine/overall_shanten.dart';

/// Every tile kind a drawn/kept tile could ever have in this ruleset. 華牌
/// are excluded — they're always extracted immediately, never kept in hand
/// (STEP5「華牌」), so they can never be part of a shanten-relevant shape.
final List<Object> allTileKinds = [
  for (var rank = 1; rank <= 9; rank++) (NumberSuit.pin, rank),
  for (var rank = 1; rank <= 9; rank++) (NumberSuit.sou, rank),
  (NumberSuit.man, 1),
  (NumberSuit.man, 9),
  Wind.east,
  Wind.south,
  Wind.west,
  Dragon.white,
  Dragon.green,
  Dragon.red,
  KitaTile,
];

Tile _representativeTile(Object kind) {
  if (kind is Wind) return WindTile(kind);
  if (kind is Dragon) return DragonTile(kind);
  if (kind == KitaTile) return const KitaTile();
  final (suit, rank) = kind as (NumberSuit, int);
  return NumberTile(suit, rank);
}

/// The tile kinds that would strictly improve [hand]'s [overallShanten] if
/// drawn (and, for 北, kept rather than extracted). Shanten is monotonic
/// non-increasing under adding a tile — the decomposition search can always
/// fall back to treating a new tile as waste — so this comparison alone is
/// enough to identify genuinely useful kinds, no separate "then discard"
/// simulation needed.
Set<Object> ukeireKinds(Hand hand) {
  final baseline = overallShanten(hand);
  final helpful = <Object>{};
  for (final kind in allTileKinds) {
    final withTile = Hand(
      concealedTiles: [...hand.concealedTiles, _representativeTile(kind)],
      melds: hand.melds,
    );
    if (overallShanten(withTile) < baseline) {
      helpful.add(kind);
    }
  }
  return helpful;
}
