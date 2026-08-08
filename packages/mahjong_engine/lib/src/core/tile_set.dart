import 'tile.dart';

/// The two red/blue dora presets confirmed in STEP5追補4 (§1). Any other
/// combination (0 marked, red-only counts other than 4, etc.) was dropped
/// from the ruleset, so this is deliberately just two values, not a count.
enum DoraMarkPreset {
  /// 赤各4（全赤）: all four 5p and all four 5s are red.
  allRed,

  /// 赤各1＋青各1: one red and one blue 5p, one red and one blue 5s.
  oneRedOneBlue,
}

/// Total tile count for the SixKa6PeiSanma set (STEP5 §1): 8 man + 36 pin +
/// 36 sou + 12 wind + 12 dragon + 6 kita + 6 hana.
const int totalTileCount = 116;

/// Builds the full 116-tile set for one hand of SixKa6PeiSanma.
///
/// This is the *type* inventory (which physical tiles exist), not a shuffled
/// wall — dealing and the 崖 (cliff) draw order are the engine's concern.
List<Tile> buildFullTileSet({required DoraMarkPreset markPreset}) {
  final tiles = <Tile>[];

  // 萬子: 一萬・九萬のみ、各4枚 (STEP5 §1)
  for (final number in [1, 9]) {
    for (var i = 0; i < 4; i++) {
      tiles.add(NumberTile(NumberSuit.man, number));
    }
  }

  // 筒子・索子: 1-9 各4枚、5のみドラプリセットに応じて着色
  for (final suit in [NumberSuit.pin, NumberSuit.sou]) {
    for (var number = 1; number <= 9; number++) {
      if (number == 5) {
        tiles.addAll(_fiveTilesFor(suit, markPreset));
      } else {
        for (var i = 0; i < 4; i++) {
          tiles.add(NumberTile(suit, number));
        }
      }
    }
  }

  // 風牌: 東・南・西のみ、各4枚（北は含まない。KitaTile参照）
  for (final wind in Wind.values) {
    for (var i = 0; i < 4; i++) {
      tiles.add(WindTile(wind));
    }
  }

  // 三元牌: 白・發・中、各4枚。白のうち1枚が白ポッチ
  for (final dragon in Dragon.values) {
    for (var i = 0; i < 4; i++) {
      tiles.add(
        DragonTile(dragon, isHakuPocchi: dragon == Dragon.white && i == 0),
      );
    }
  }

  // 北（抜きドラ）: 6枚
  for (var i = 0; i < 6; i++) {
    tiles.add(const KitaTile());
  }

  // 華牌: 春夏秋冬 各1枚 + マイティ2枚
  tiles.add(const HanaTile(HanaKind.spring));
  tiles.add(const HanaTile(HanaKind.summer));
  tiles.add(const HanaTile(HanaKind.autumn));
  tiles.add(const HanaTile(HanaKind.winter));
  tiles.add(const HanaTile(HanaKind.mighty));
  tiles.add(const HanaTile(HanaKind.mighty));

  assert(tiles.length == totalTileCount, 'expected $totalTileCount tiles, got ${tiles.length}');
  return tiles;
}

List<NumberTile> _fiveTilesFor(NumberSuit suit, DoraMarkPreset preset) {
  return switch (preset) {
    DoraMarkPreset.allRed => List.generate(
        4,
        (_) => NumberTile(suit, 5, mark: TileMark.red),
      ),
    DoraMarkPreset.oneRedOneBlue => [
        NumberTile(suit, 5, mark: TileMark.red),
        NumberTile(suit, 5, mark: TileMark.blue),
        NumberTile(suit, 5),
        NumberTile(suit, 5),
      ],
  };
}
