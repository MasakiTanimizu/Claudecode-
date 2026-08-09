import 'package:flutter/material.dart';
import 'package:mahjong_engine/mahjong_engine.dart';

import 'tile_view.dart';

/// A player's hand: concealed tiles (auto-sorted into man → pin → sou →
/// winds → dragons → kita, ascending by rank within a suit) followed by any
/// declared melds, each meld visually separated (STEP7「手牌」表示). Melds
/// keep their declared order/tiles as-is — only the concealed tiles get
/// sorted, since a meld is already a fixed, already-grouped set.
///
/// [onDiscard], when set, is wired to every concealed tile's double-tap
/// (see [TileView]) — meld tiles are never discardable, so they never get
/// the callback regardless.
class HandView extends StatelessWidget {
  final List<Tile> concealedTiles;
  final List<Meld> melds;
  final void Function(Tile tile)? onDiscard;

  const HandView({
    required this.concealedTiles,
    required this.melds,
    this.onDiscard,
    super.key,
  });

  /// Sort key: man tiles first, then pin, then sou (ascending rank within
  /// each), then winds, then dragons, then kita last — hana never appears
  /// in a hand (STEP5「華牌」: always auto-nuku'd) so its key is unused in
  /// practice.
  static int _sortKey(Tile tile) => switch (tile) {
        NumberTile t => t.suit.index * 100 + t.number,
        WindTile t => 300 + t.wind.index,
        DragonTile t => 310 + t.dragon.index,
        KitaTile _ => 400,
        HanaTile t => 500 + t.kind.index,
      };

  @override
  Widget build(BuildContext context) {
    final sortedConcealedTiles = [...concealedTiles]..sort((a, b) => _sortKey(a) - _sortKey(b));
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final tile in sortedConcealedTiles)
          TileView(tile, onDiscard: onDiscard == null ? null : () => onDiscard!(tile)),
        for (final meld in melds) ...[
          const SizedBox(width: 6),
          for (final tile in meld.tiles) TileView(tile),
        ],
      ],
    );
  }
}
