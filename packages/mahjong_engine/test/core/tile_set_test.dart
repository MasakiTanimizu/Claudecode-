import 'package:mahjong_engine/mahjong_engine.dart';
import 'package:test/test.dart';

void main() {
  group('buildFullTileSet', () {
    for (final preset in DoraMarkPreset.values) {
      test('$preset totals $totalTileCount tiles', () {
        expect(buildFullTileSet(markPreset: preset), hasLength(totalTileCount));
      });
    }

    test('man contains only 1m x4 and 9m x4', () {
      final tiles = buildFullTileSet(markPreset: DoraMarkPreset.allRed);
      final man = tiles.whereType<NumberTile>().where((t) => t.suit == NumberSuit.man);
      expect(man.where((t) => t.number == 1), hasLength(4));
      expect(man.where((t) => t.number == 9), hasLength(4));
      expect(man.map((t) => t.number).toSet(), {1, 9});
    });

    test('no WindTile is ever north (north only exists as KitaTile)', () {
      final tiles = buildFullTileSet(markPreset: DoraMarkPreset.allRed);
      expect(tiles.whereType<WindTile>(), hasLength(12));
      expect(tiles.whereType<KitaTile>(), hasLength(6));
    });

    test('allRed preset marks all four 5p and 5s red', () {
      final tiles = buildFullTileSet(markPreset: DoraMarkPreset.allRed);
      final fives = tiles
          .whereType<NumberTile>()
          .where((t) => t.number == 5 && t.suit != NumberSuit.man);
      expect(fives, hasLength(8));
      expect(fives.every((t) => t.mark == TileMark.red), isTrue);
    });

    test('oneRedOneBlue preset marks one red, one blue, two plain per suit', () {
      final tiles = buildFullTileSet(markPreset: DoraMarkPreset.oneRedOneBlue);
      for (final suit in [NumberSuit.pin, NumberSuit.sou]) {
        final fives = tiles.whereType<NumberTile>().where(
              (t) => t.number == 5 && t.suit == suit,
            );
        expect(fives.where((t) => t.mark == TileMark.red), hasLength(1));
        expect(fives.where((t) => t.mark == TileMark.blue), hasLength(1));
        expect(fives.where((t) => t.mark == TileMark.none), hasLength(2));
      }
    });

    test('exactly one white dragon is haku-pocchi', () {
      final tiles = buildFullTileSet(markPreset: DoraMarkPreset.allRed);
      final whites = tiles.whereType<DragonTile>().where((t) => t.dragon == Dragon.white);
      expect(whites, hasLength(4));
      expect(whites.where((t) => t.isHakuPocchi), hasLength(1));
    });

    test('hana has one of each season plus two Mighty', () {
      final tiles = buildFullTileSet(markPreset: DoraMarkPreset.allRed);
      final hana = tiles.whereType<HanaTile>();
      expect(hana, hasLength(6));
      for (final kind in [HanaKind.spring, HanaKind.summer, HanaKind.autumn, HanaKind.winter]) {
        expect(hana.where((t) => t.kind == kind), hasLength(1));
      }
      expect(hana.where((t) => t.kind == HanaKind.mighty), hasLength(2));
    });
  });
}
