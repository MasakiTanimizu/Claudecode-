import 'package:flutter/material.dart';
import 'package:mahjong_engine/mahjong_engine.dart';

/// A single tile, rendered as its [Tile.label] text on a bordered card.
/// Placeholder art — real tile graphics (STEP7「雀魂/MJ/天鳳の間」の見た目)
/// land in a later slice; this exists so the board layout and interaction
/// logic can be built and tested now without waiting on art assets.
///
/// [onDiscard], when set, makes the tile discardable via double-tap — the
/// established gesture for this app (STEP7「牌を捨てる時の操作方法...ダブル
/// タップまたはスクロール操作で捨てる」). A single tap intentionally does
/// nothing, so an accidental touch can't discard a tile.
class TileView extends StatelessWidget {
  final Tile tile;
  final VoidCallback? onDiscard;

  const TileView(this.tile, {this.onDiscard, super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: onDiscard,
      child: Container(
        width: 32,
        height: 44,
        margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 1),
        decoration: BoxDecoration(
          color: onDiscard != null ? Colors.amber.shade50 : Colors.white,
          border: Border.all(color: Colors.black45),
          borderRadius: BorderRadius.circular(4),
        ),
        alignment: Alignment.center,
        child: Text(
          tile.label,
          style: const TextStyle(fontSize: 11, color: Colors.black87),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
