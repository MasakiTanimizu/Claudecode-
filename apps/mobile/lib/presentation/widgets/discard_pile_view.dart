import 'package:flutter/material.dart';
import 'package:mahjong_engine/mahjong_engine.dart';

import 'tile_view.dart';

/// One player's discard pile (河), labeled with who it belongs to.
class DiscardPileView extends StatelessWidget {
  final String playerLabel;
  final List<Tile> discards;

  const DiscardPileView({required this.playerLabel, required this.discards, super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(playerLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
        Wrap(children: [for (final tile in discards) TileView(tile)]),
      ],
    );
  }
}
