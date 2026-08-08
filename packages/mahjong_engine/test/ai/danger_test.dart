import 'package:mahjong_engine/mahjong_engine.dart';
import 'package:test/test.dart';

NumberTile man(int n) => NumberTile(NumberSuit.man, n);
NumberTile pin(int n, {TileMark mark = TileMark.none}) => NumberTile(NumberSuit.pin, n, mark: mark);
NumberTile sou(int n) => NumberTile(NumberSuit.sou, n);

void main() {
  group('isGenbutsu', () {
    test('true when the exact tile kind was discarded', () {
      expect(isGenbutsu(pin(5), [pin(2), pin(5)]), isTrue);
    });

    test('is mark-insensitive: a red 5p is genbutsu if a plain 5p was discarded', () {
      expect(isGenbutsu(pin(5, mark: TileMark.red), [pin(5)]), isTrue);
    });

    test('false when nothing matches', () {
      expect(isGenbutsu(pin(5), [pin(2), sou(5)]), isFalse);
    });
  });

  group('isSuji', () {
    test('discarding 4p makes 1p and 7p suji-safe', () {
      expect(isSuji(pin(1), [pin(4)]), isTrue);
      expect(isSuji(pin(7), [pin(4)]), isTrue);
      expect(isSuji(pin(2), [pin(4)]), isFalse);
    });

    test('discarding 5s makes 2s and 8s suji-safe', () {
      expect(isSuji(sou(2), [sou(5)]), isTrue);
      expect(isSuji(sou(8), [sou(5)]), isTrue);
    });

    test('man is never suji (no shuntsu exists for man)', () {
      expect(isSuji(man(1), [man(9)]), isFalse);
    });

    test('honors are never suji', () {
      expect(isSuji(const WindTile(Wind.east), [pin(4)]), isFalse);
    });
  });

  group('isLikelySafe', () {
    test('true for genbutsu or suji, false otherwise', () {
      expect(isLikelySafe(pin(5), [pin(5)]), isTrue); // genbutsu
      expect(isLikelySafe(pin(1), [pin(4)]), isTrue); // suji
      expect(isLikelySafe(pin(6), [pin(4)]), isFalse); // neither
    });
  });
}
