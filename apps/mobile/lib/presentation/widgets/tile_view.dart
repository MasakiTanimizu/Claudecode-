import 'package:flutter/material.dart';
import 'package:mahjong_engine/mahjong_engine.dart';

/// A single tile, rendered on a bordered card using traditional mahjong tile
/// face conventions — drawn entirely with Flutter's own shapes/text, not
/// copied from any specific app's art assets, so there's nothing to source
/// or license:
/// - pin (筒子): a canonical dot pattern, one row-group per count.
/// - sou (索子): the same canonical layout, drawn as bamboo bars instead.
/// - man (萬子): a kanji numeral over 萬, in red (only 1m/9m exist here).
/// - winds/dragons/北/華牌: a single bold, colored rendering of [Tile.label]
///   (white dragon gets a blank bordered box, hana get a soft color badge —
///   both still keep the label text, just with light decoration around it).
///
/// [Tile.label] is always present as real text somewhere in the tile
/// (either as the whole rendering, or as the pattern tile's small caption)
/// deliberately — the rest of the app finds/taps specific tiles via
/// `find.text(tile.label)`, and changing what's displayed to something
/// else (e.g. only the kanji numeral, without "1m" anywhere) would break
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
    final graphic = _graphicFor(tile);
    return GestureDetector(
      onDoubleTap: onDiscard,
      child: Container(
        width: 34,
        height: 48,
        margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 1),
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
        decoration: BoxDecoration(
          color: _backgroundColor(discardable: onDiscard != null),
          border: Border.all(color: Colors.black45),
          borderRadius: BorderRadius.circular(4),
        ),
        child: graphic == null
            ? Center(child: _plainLabel(tile))
            : Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Center(
                      child: FittedBox(fit: BoxFit.scaleDown, child: graphic),
                    ),
                  ),
                  Text(
                    tile.label,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 9, color: Colors.black54),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
      ),
    );
  }

  Color _backgroundColor({required bool discardable}) {
    if (discardable) return Colors.amber.shade50;
    if (tile is KitaTile) return const Color(0xFFFCE9B0);
    return Colors.white;
  }
}

/// The dot/bamboo/kanji pattern for a number tile, or null for anything else
/// (winds/dragons/北/華牌 render as styled text instead — see the class doc).
Widget? _graphicFor(Tile tile) {
  if (tile is! NumberTile) return null;
  switch (tile.suit) {
    case NumberSuit.man:
      return _ManGraphic(number: tile.number);
    case NumberSuit.pin:
      final rows = _dotRowCounts(tile.number);
      return _TileGrid(
        rowCounts: rows,
        dotBuilder: (row, _) => PinDot(
          big: tile.number == 1,
          accent: tile.number == 1 || (tile.number == 5 && rows[row] == 1),
        ),
      );
    case NumberSuit.sou:
      return _TileGrid(
        rowCounts: _dotRowCounts(tile.number),
        dotBuilder: (_, __) => Bamboo(big: tile.number == 1),
      );
  }
}

/// How many pips sit in each row for a 1-9 count, approximating the
/// canonical layouts real pin/sou tiles use (single centered dot for 1,
/// diagonal for 2-3, corners for 4, quincunx for 5, columns for 6/8/9, and
/// 7 as a lone dot over two columns of three).
List<int> _dotRowCounts(int n) => switch (n) {
      1 => const [1],
      2 => const [1, 1],
      3 => const [1, 1, 1],
      4 => const [2, 2],
      5 => const [2, 1, 2],
      6 => const [2, 2, 2],
      7 => const [1, 3, 3],
      8 => const [2, 2, 2, 2],
      9 => const [3, 3, 3],
      _ => [n],
    };

Widget _plainLabel(Tile tile) {
  if (tile is HanaTile) {
    final color = _hanaColor(tile.kind);
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.18), shape: BoxShape.circle),
        ),
        Text(
          tile.label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
  if (tile is DragonTile && tile.dragon == Dragon.white) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blue.shade700, width: 1.5),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        tile.label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue.shade700),
        textAlign: TextAlign.center,
      ),
    );
  }
  return Text(
    tile.label,
    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _accentColor(tile)),
    textAlign: TextAlign.center,
  );
}

Color _hanaColor(HanaKind kind) => switch (kind) {
      HanaKind.spring => Colors.pink.shade400,
      HanaKind.summer => Colors.green.shade600,
      HanaKind.autumn => Colors.orange.shade700,
      HanaKind.winter => Colors.blue.shade600,
      HanaKind.mighty => Colors.purple.shade600,
    };

Color _accentColor(Tile tile) => switch (tile) {
      NumberTile _ => Colors.black87, // unreachable: NumberTile always uses _graphicFor
      WindTile _ => Colors.black87,
      DragonTile t => switch (t.dragon) {
          Dragon.white => Colors.blue.shade700,
          Dragon.green => Colors.green.shade700,
          Dragon.red => Colors.red.shade700,
        },
      KitaTile _ => Colors.orange.shade900,
      HanaTile _ => Colors.pink.shade600,
    };

/// A kanji numeral over 萬 — man only has 1m/9m in this ruleset (STEP5 §1),
/// so a pip grid like pin/sou's isn't worth building for it.
class _ManGraphic extends StatelessWidget {
  final int number;

  const _ManGraphic({required this.number});

  static const _numeral = {1: '一', 9: '九'};

  @override
  Widget build(BuildContext context) {
    final color = Colors.red.shade700;
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _numeral[number] ?? '$number',
          style: TextStyle(fontSize: 11, height: 1.0, fontWeight: FontWeight.bold, color: color),
        ),
        Text('萬', style: TextStyle(fontSize: 10, height: 1.0, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}

/// Lays [dotBuilder]'s pips out in rows of [rowCounts], each row centered —
/// the shared grid pin and sou patterns are both built from.
class _TileGrid extends StatelessWidget {
  final List<int> rowCounts;
  final Widget Function(int row, int col) dotBuilder;

  const _TileGrid({required this.rowCounts, required this.dotBuilder});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var r = 0; r < rowCounts.length; r++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 0.3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var c = 0; c < rowCounts[r]; c++) ...[
                  if (c > 0) const SizedBox(width: 1.5),
                  dotBuilder(r, c),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// One dot in a pin tile's pattern. [accent] renders it red instead of the
/// default blue (used for 1p's sole dot and 5p's center dot); [big] enlarges
/// it (used only for 1p, which has just the one dot to fill the tile with).
class PinDot extends StatelessWidget {
  final bool accent;
  final bool big;

  const PinDot({this.accent = false, this.big = false, super.key});

  @override
  Widget build(BuildContext context) {
    final size = big ? 14.0 : 5.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: accent ? Colors.red.shade600 : Colors.blue.shade700,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black26, width: 0.5),
      ),
    );
  }
}

/// One bamboo bar in a sou tile's pattern, with two node lines. [big]
/// enlarges it (used only for 1s, which has just the one bar to fill the
/// tile with).
class Bamboo extends StatelessWidget {
  final bool big;

  const Bamboo({this.big = false, super.key});

  @override
  Widget build(BuildContext context) {
    final width = big ? 7.0 : 3.0;
    final height = big ? 18.0 : 5.5;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: Colors.green.shade700, borderRadius: BorderRadius.circular(1)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Container(height: 0.6, color: Colors.green.shade900),
          Container(height: 0.6, color: Colors.green.shade900),
        ],
      ),
    );
  }
}
