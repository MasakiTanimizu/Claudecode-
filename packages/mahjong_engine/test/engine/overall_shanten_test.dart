import 'package:mahjong_engine/mahjong_engine.dart';
import 'package:test/test.dart';

NumberTile man(int n) => NumberTile(NumberSuit.man, n);
NumberTile pin(int n) => NumberTile(NumberSuit.pin, n);
NumberTile sou(int n) => NumberTile(NumberSuit.sou, n);

List<Tile> run(NumberTile Function(int) suit, int start) =>
    [suit(start), suit(start + 1), suit(start + 2)];

void main() {
  group('overallShanten', () {
    test('picks kokushi when it is the best-fitting shape', () {
      final hand = Hand(concealedTiles: [
        man(1),
        man(9),
        pin(1),
        pin(9),
        sou(1),
        sou(9),
        const WindTile(Wind.east),
        const WindTile(Wind.south),
        const WindTile(Wind.west),
        DragonTile(Dragon.white),
        DragonTile(Dragon.green),
        DragonTile(Dragon.red),
        const KitaTile(),
      ]);
      expect(kokushiShanten(hand), 0);
      expect(overallShanten(hand), 0); // kokushi's 0 beats chiitoitsu/standard here.
    });

    test('picks standard when it is the best-fitting shape', () {
      final hand = Hand(concealedTiles: [
        ...run(pin, 1),
        ...run(pin, 4),
        ...run(pin, 7),
        DragonTile(Dragon.white),
        DragonTile(Dragon.white),
        sou(4),
        sou(5),
      ]);
      expect(standardShanten(hand), 0);
      expect(overallShanten(hand), 0);
    });
  });
}
