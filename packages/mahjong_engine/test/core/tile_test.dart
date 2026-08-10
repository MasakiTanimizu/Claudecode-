import 'package:mahjong_engine/mahjong_engine.dart';
import 'package:test/test.dart';

void main() {
  group('NumberTile', () {
    test('accepts 1m and 9m', () {
      expect(NumberTile(NumberSuit.man, 1).label, '1m');
      expect(NumberTile(NumberSuit.man, 9).label, '9m');
    });

    test('rejects man ranks other than 1 and 9', () {
      expect(() => NumberTile(NumberSuit.man, 2), throwsA(isA<AssertionError>()));
      expect(() => NumberTile(NumberSuit.man, 5), throwsA(isA<AssertionError>()));
    });

    test('rejects a mark on man tiles', () {
      expect(
        () => NumberTile(NumberSuit.man, 1, mark: TileMark.red),
        throwsA(isA<AssertionError>()),
      );
    });

    test('rejects a mark on a non-5 pin/sou tile', () {
      expect(
        () => NumberTile(NumberSuit.pin, 4, mark: TileMark.red),
        throwsA(isA<AssertionError>()),
      );
    });

    test('allows red/blue marks on 5p and 5s', () {
      expect(NumberTile(NumberSuit.pin, 5, mark: TileMark.red).label, '5p(赤)');
      expect(NumberTile(NumberSuit.sou, 5, mark: TileMark.blue).label, '5s(青)');
    });

    test('equality is by suit, number and mark', () {
      expect(NumberTile(NumberSuit.pin, 3), NumberTile(NumberSuit.pin, 3));
      expect(
        NumberTile(NumberSuit.pin, 5, mark: TileMark.red),
        isNot(NumberTile(NumberSuit.pin, 5)),
      );
    });
  });

  group('DragonTile', () {
    test('haku-pocchi only valid on white dragon', () {
      expect(
        () => DragonTile(Dragon.red, isHakuPocchi: true),
        throwsA(isA<AssertionError>()),
      );
      expect(
        DragonTile(Dragon.white, isHakuPocchi: true).label,
        '白•',
      );
    });

    test('a haku-pocchi tile is not equal to a plain white dragon', () {
      expect(
        DragonTile(Dragon.white, isHakuPocchi: true),
        isNot(DragonTile(Dragon.white)),
      );
    });
  });

  group('WindTile', () {
    test('only east, south, west exist as playable winds', () {
      expect(Wind.values, [Wind.east, Wind.south, Wind.west]);
    });
  });

  group('KitaTile', () {
    test('is a distinct tile from any wind, including a would-be north', () {
      // KitaTile has no `wind` field at all — this just documents that
      // north is structurally absent from WindTile (STEP5 "北の扱い").
      expect(const KitaTile().label, '北');
    });

    test('all KitaTile instances are equal (type-level identity)', () {
      expect(const KitaTile(), const KitaTile());
    });
  });

  group('HanaTile', () {
    test('the two Mighty tiles are equal to each other', () {
      expect(const HanaTile(HanaKind.mighty), const HanaTile(HanaKind.mighty));
    });
  });
}
