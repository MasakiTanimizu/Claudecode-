import 'package:mahjong_engine/mahjong_engine.dart';
import 'package:test/test.dart';

NumberTile pin(int n) => NumberTile(NumberSuit.pin, n);
NumberTile sou(int n) => NumberTile(NumberSuit.sou, n);

List<Tile> run(NumberTile Function(int) suit, int start) =>
    [suit(start), suit(start + 1), suit(start + 2)];

void main() {
  group('ukeireKinds', () {
    test('ryanmen tenpai: only the two wait kinds help', () {
      final hand = Hand(concealedTiles: [
        ...run(pin, 1),
        ...run(pin, 4),
        ...run(pin, 7),
        DragonTile(Dragon.white),
        DragonTile(Dragon.white),
        sou(4),
        sou(5),
      ]);
      expect(ukeireKinds(hand), {(NumberSuit.sou, 3), (NumberSuit.sou, 6)});
    });

    test('tanki wait: only the single tile\'s own kind helps', () {
      final hand = Hand(concealedTiles: [
        ...run(pin, 1),
        ...run(pin, 4),
        ...run(pin, 7),
        const WindTile(Wind.east),
        const WindTile(Wind.east),
        const WindTile(Wind.east),
        DragonTile(Dragon.white),
      ]);
      expect(ukeireKinds(hand), {Dragon.white});
    });

    test('北 counts as a helpful kind for a near-complete kokushi hand', () {
      // 12 valid kokushi kinds + one filler tile that isn't part of the set.
      final hand = Hand(concealedTiles: [
        NumberTile(NumberSuit.man, 1),
        NumberTile(NumberSuit.man, 9),
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
        pin(5), // filler — not a kokushi kind.
      ]);
      expect(overallShanten(hand), 1);
      expect(ukeireKinds(hand), contains(KitaTile));
    });
  });
}
