import 'package:mahjong_engine/mahjong_engine.dart';
import 'package:test/test.dart';

NumberTile man(int n) => NumberTile(NumberSuit.man, n);
NumberTile pin(int n) => NumberTile(NumberSuit.pin, n);
NumberTile sou(int n) => NumberTile(NumberSuit.sou, n);
const kita = KitaTile();

void main() {
  group('shouldKeepDrawnKita', () {
    final terminalHeavyHand = Hand(concealedTiles: [
      pin(1), pin(9), sou(1), sou(9), man(1), man(9),
      const WindTile(Wind.east), const WindTile(Wind.south), DragonTile(Dragon.white),
      pin(4), pin(5), pin(6), sou(4),
      kita,
    ]);

    final simpleHeavyHand = Hand(concealedTiles: [
      pin(1), sou(1), man(1), const WindTile(Wind.east),
      pin(2), pin(3), pin(4), pin(5), pin(6), pin(7), sou(2), sou(3), sou(4),
      kita,
    ]);

    final allSimpleHand = Hand(concealedTiles: [
      pin(2), pin(3), pin(4), pin(5), pin(6), pin(7), pin(8),
      sou(2), sou(3), sou(4), sou(5), sou(6), sou(7),
      kita,
    ]);

    test('初級 always extracts, regardless of hand shape', () {
      expect(shouldKeepDrawnKita(terminalHeavyHand, CpuDifficulty.beginner), isFalse);
    });

    test('中級 keeps when the hand already leans terminal/honor', () {
      expect(shouldKeepDrawnKita(terminalHeavyHand, CpuDifficulty.intermediate), isTrue);
      expect(shouldKeepDrawnKita(simpleHeavyHand, CpuDifficulty.intermediate), isFalse);
    });

    test('上級 keeps only when kokushi is still realistically close', () {
      expect(kokushiShanten(terminalHeavyHand), lessThanOrEqualTo(4));
      expect(shouldKeepDrawnKita(terminalHeavyHand, CpuDifficulty.advanced), isTrue);

      expect(kokushiShanten(allSimpleHand), greaterThan(4));
      expect(shouldKeepDrawnKita(allSimpleHand, CpuDifficulty.advanced), isFalse);
    });
  });
}
