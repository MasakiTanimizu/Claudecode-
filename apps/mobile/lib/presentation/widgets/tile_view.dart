import 'package:flutter/material.dart';
import 'package:mahjong_engine/mahjong_engine.dart';

/// A single tile, rendered on a bordered card. A pin/sou number tile draws
/// a pip pattern (circles/bars, one per count) above its label; every other
/// tile — man (only 1/9 exist in this ruleset, so a pip grid isn't worth
/// it), winds, dragons, 北, and 華牌 — is a single bold, colored rendering
/// of [Tile.label] instead, colored per kind (STEP7「雀魂/MJ/天鳳の間」の見た
/// 目 STEP10実装: no external art assets, drawn entirely with Flutter's own
/// shapes/text so there's nothing to source or license).
///
/// [Tile.label] is always present as real text somewhere in the tile
/// (either as the whole rendering, or as the pip tile's small caption)
/// deliberately — the rest of the app finds/taps specific tiles via
/// `find.text(tile.label)`, and changing what's displayed to something
/// else (e.g. traditional 一萬/九萬 kanji instead of "1m") would break
/// that everywhere at once.
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
    final pips = _pipsFor(tile);
    return GestureDetector(
      onDoubleTap: onDiscard,
      child: Container(
        width: 34,
        height: 48,
        margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 1),
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
        decoration: BoxDecoration(
          color: onDiscard != null ? Colors.amber.shade50 : Colors.white,
          border: Border.all(color: Colors.black45),
          borderRadius: BorderRadius.circular(4),
        ),
        child: pips == null
            ? Center(
                child: Text(
                  tile.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: _accentColor(tile),
                  ),
                  textAlign: TextAlign.center,
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Center(child: pips)),
                  Text(
                    tile.label,
                    style: const TextStyle(fontSize: 9, color: Colors.black54),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
      ),
    );
  }
}

/// A pip pattern for a pin/sou number tile, or null for anything else
/// (man/winds/dragons/北/華牌 all render as styled text instead — see the
/// class doc).
Widget? _pipsFor(Tile tile) {
  if (tile is! NumberTile || tile.suit == NumberSuit.man) return null;
  final color = tile.suit == NumberSuit.pin ? Colors.blue.shade700 : Colors.green.shade700;
  return Wrap(
    alignment: WrapAlignment.center,
    runAlignment: WrapAlignment.center,
    spacing: 1.5,
    runSpacing: 1.5,
    children: [
      for (var i = 0; i < tile.number; i++) _Pip(suit: tile.suit, color: color),
    ],
  );
}

Color _accentColor(Tile tile) => switch (tile) {
      NumberTile t => t.suit == NumberSuit.man ? Colors.red.shade700 : Colors.black87,
      WindTile _ => Colors.black87,
      DragonTile t => switch (t.dragon) {
          Dragon.white => Colors.blue.shade700,
          Dragon.green => Colors.green.shade700,
          Dragon.red => Colors.red.shade700,
        },
      KitaTile _ => Colors.orange.shade800,
      HanaTile _ => Colors.pink.shade600,
    };

/// One dot (pin) or bar (sou) in a number tile's pip pattern.
class _Pip extends StatelessWidget {
  final NumberSuit suit;
  final Color color;

  const _Pip({required this.suit, required this.color});

  @override
  Widget build(BuildContext context) {
    if (suit == NumberSuit.sou) {
      return Container(width: 3, height: 7, color: color);
    }
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
