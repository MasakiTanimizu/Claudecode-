import 'package:flutter/material.dart';
import 'package:mahjong_engine/mahjong_engine.dart';

import 'tile_view.dart';

/// A player's hand: concealed tiles followed by any declared melds, each
/// meld visually separated (STEP7「手牌」表示).
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

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final tile in concealedTiles)
          TileView(tile, onDiscard: onDiscard == null ? null : () => onDiscard!(tile)),
        for (final meld in melds) ...[
          const SizedBox(width: 6),
          for (final tile in meld.tiles) TileView(tile),
        ],
      ],
    );
  }
}
