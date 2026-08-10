import 'dart:math';

import 'tile.dart';

/// The 崖 (cliff) wall: there is no separate 王牌 block. A normal draw and a
/// kan/kita/hana replacement draw both just take the next tile off the same
/// sequence (docs/design/05 "王牌の区画を撤廃（崖ルール）") — the caller
/// decides *who* receives a given draw, this class only tracks *which tile
/// is next* and how much of the tail is reserved for dora indicators.
class Wall {
  final List<Tile> tiles;
  int _drawn = 0;
  int _doraIndicatorsRevealed;

  Wall(this.tiles, {int initialDoraIndicators = 2})
      : _doraIndicatorsRevealed = initialDoraIndicators,
        assert(
          tiles.length > initialDoraIndicators,
          'wall too small to reserve $initialDoraIndicators dora indicators',
        );

  /// Tiles still drawable, i.e. excluding the reserved dora-indicator tail.
  int get remainingLiveCount => tiles.length - _doraIndicatorsRevealed - _drawn;

  /// 流局: the live portion has run out (STEP5追補6).
  bool get isExhausted => remainingLiveCount <= 0;

  /// Takes the next tile — used for both a normal turn draw and a
  /// kan/kita/hana replacement draw, since the 崖 rule makes them
  /// mechanically identical (STEP5追補6: 専用の嶺上牌スペースは無い).
  Tile draw() {
    if (isExhausted) {
      throw StateError('wall is exhausted (流局): no tiles left to draw');
    }
    return tiles[_drawn++];
  }

  /// The currently revealed dora indicators (常時2枚 at the start).
  List<Tile> get doraIndicators =>
      List.unmodifiable(tiles.sublist(tiles.length - _doraIndicatorsRevealed));

  /// Each kan reveals exactly one more indicator (STEP5追補4での訂正:
  /// 「2面ずつ」ではなく通常通り1面ずつ), shrinking the live wall by one
  /// more tile from the tail.
  void revealNextDoraIndicator() {
    if (remainingLiveCount <= 0) {
      throw StateError('cannot reveal another dora indicator: wall is already exhausted');
    }
    _doraIndicatorsRevealed++;
  }
}

/// Shuffles [fullTileSet] and deals [handSize] tiles to each of
/// [playerCount] players; whatever remains becomes the [Wall].
({List<List<Tile>> hands, Wall wall}) dealHands(
  List<Tile> fullTileSet, {
  required int playerCount,
  required Random random,
  int handSize = 13,
}) {
  final shuffled = List<Tile>.of(fullTileSet)..shuffle(random);
  final required = playerCount * handSize;
  if (shuffled.length <= required) {
    throw ArgumentError(
      'tile set too small: need more than $required tiles to deal '
      '$playerCount×$handSize and still have a wall',
    );
  }

  final hands = <List<Tile>>[];
  var index = 0;
  for (var p = 0; p < playerCount; p++) {
    hands.add(shuffled.sublist(index, index + handSize));
    index += handSize;
  }

  return (
    hands: List.unmodifiable(hands),
    wall: Wall(shuffled.sublist(index)),
  );
}
