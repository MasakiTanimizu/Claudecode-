import 'package:mahjong_engine/mahjong_engine.dart';
import 'package:test/test.dart';

NumberTile man(int n) => NumberTile(NumberSuit.man, n);
NumberTile pin(int n) => NumberTile(NumberSuit.pin, n);
NumberTile sou(int n) => NumberTile(NumberSuit.sou, n);

List<Tile> run(NumberTile Function(int) suit, int start) =>
    [suit(start), suit(start + 1), suit(start + 2)];

void main() {
  group('chooseDiscard', () {
    test('discards the one tile that restores tenpai', () {
      final hand = Hand(concealedTiles: [
        ...run(pin, 1),
        ...run(pin, 4),
        ...run(pin, 7),
        DragonTile(Dragon.white),
        DragonTile(Dragon.white),
        sou(4),
        sou(5),
        man(1), // the junk 14th tile.
      ]);
      expect(chooseDiscard(hand), man(1));
    });

    test('never offers 北 as a discard candidate', () {
      final hand = Hand(concealedTiles: [
        ...run(pin, 1),
        ...run(pin, 4),
        ...run(pin, 7),
        DragonTile(Dragon.white),
        DragonTile(Dragon.white),
        sou(4),
        const KitaTile(),
      ]);
      expect(chooseDiscard(hand), isNot(const KitaTile()));
    });

    test('throws if every concealed tile is 北', () {
      final hand = Hand(concealedTiles: [const KitaTile(), const KitaTile()]);
      expect(() => chooseDiscard(hand), throwsStateError);
    });
  });
}
