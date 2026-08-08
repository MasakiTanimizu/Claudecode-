import 'package:flutter/material.dart';
import 'package:mahjong_engine/mahjong_engine.dart';

/// A single tile, rendered as its [Tile.label] text on a bordered card.
/// Placeholder art — real tile graphics (STEP7「雀魂/MJ/天鳳の間」の見た目)
/// land in a later slice; this exists so the board layout and interaction
/// logic can be built and tested now without waiting on art assets.
class TileView extends StatelessWidget {
  final Tile tile;

  const TileView(this.tile, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 44,
      margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black45),
        borderRadius: BorderRadius.circular(4),
      ),
      alignment: Alignment.center,
      child: Text(
        tile.label,
        style: const TextStyle(fontSize: 11, color: Colors.black87),
        textAlign: TextAlign.center,
      ),
    );
  }
}
