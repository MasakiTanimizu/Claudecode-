import 'package:mahjong_engine/mahjong_engine.dart';
import 'package:test/test.dart';

NumberTile man(int n) => NumberTile(NumberSuit.man, n);
NumberTile pin(int n) => NumberTile(NumberSuit.pin, n);
NumberTile sou(int n) => NumberTile(NumberSuit.sou, n);
const kita = KitaTile();

List<Tile> run(NumberTile Function(int) suit, int start) =>
    [suit(start), suit(start + 1), suit(start + 2)];

void main() {
  group('standardShanten', () {
    test('complete: 3 sequences + 1 triplet + a pair', () {
      final hand = Hand(concealedTiles: [
        ...run(pin, 1),
        ...run(pin, 4),
        ...run(pin, 7),
        const WindTile(Wind.east),
        const WindTile(Wind.east),
        const WindTile(Wind.east),
        DragonTile(Dragon.white),
        DragonTile(Dragon.white),
      ]);
      expect(standardShanten(hand), -1);
    });

    test('tenpai: ryanmen wait (3 melds + pair + 2-tile proto-run)', () {
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
    });

    test('tenpai: tanki wait (4 melds + a single tile)', () {
      final hand = Hand(concealedTiles: [
        ...run(pin, 1),
        ...run(pin, 4),
        ...run(pin, 7),
        const WindTile(Wind.east),
        const WindTile(Wind.east),
        const WindTile(Wind.east),
        DragonTile(Dragon.white),
      ]);
      expect(standardShanten(hand), 0);
    });

    test('tenpai: shanpon wait (3 melds + 2 pairs)', () {
      final hand = Hand(concealedTiles: [
        ...run(pin, 1),
        ...run(pin, 4),
        ...run(pin, 7),
        DragonTile(Dragon.white),
        DragonTile(Dragon.white),
        DragonTile(Dragon.green),
        DragonTile(Dragon.green),
      ]);
      expect(standardShanten(hand), 0);
    });

    test('1-shanten: 2 melds + pair + 2 unfinished proto-melds', () {
      final hand = Hand(concealedTiles: [
        ...run(pin, 1),
        ...run(pin, 4),
        DragonTile(Dragon.white),
        DragonTile(Dragon.white),
        pin(7),
        pin(8),
        sou(1),
        sou(3),
        man(1),
      ]);
      expect(standardShanten(hand), 1);
    });

    test('北 tiles never help — kept-kita pair does not count as a pair', () {
      final withKita = Hand(concealedTiles: [
        ...run(pin, 1),
        ...run(pin, 4),
        ...run(pin, 7),
        DragonTile(Dragon.white),
        DragonTile(Dragon.white),
        kita,
        kita,
      ]);
      // Same shape but with an obviously-real second pair instead of kita,
      // to confirm the algorithm *would* use it if it could.
      final withRealPair = Hand(concealedTiles: [
        ...run(pin, 1),
        ...run(pin, 4),
        ...run(pin, 7),
        DragonTile(Dragon.white),
        DragonTile(Dragon.white),
        DragonTile(Dragon.green),
        DragonTile(Dragon.green),
      ]);
      expect(standardShanten(withKita), 1);
      expect(standardShanten(withRealPair), 0);
    });

    test('open melds count toward the standard shape', () {
      final hand = Hand(
        concealedTiles: [
          ...run(pin, 1),
          ...run(pin, 4),
          DragonTile(Dragon.green),
          DragonTile(Dragon.green),
          sou(4),
          sou(5),
        ],
        melds: [
          Meld.kotsu(
            [DragonTile(Dragon.white), DragonTile(Dragon.white), DragonTile(Dragon.white)],
            source: CallSource.pon,
          ),
        ],
      );
      expect(standardShanten(hand), 0);
    });

    test('worst case: 13 fully isolated, non-adjacent tiles', () {
      final hand = Hand(concealedTiles: [
        pin(1), pin(4), pin(7),
        sou(1), sou(4), sou(7),
        man(1), man(9),
        const WindTile(Wind.east),
        const WindTile(Wind.south),
        const WindTile(Wind.west),
        DragonTile(Dragon.white),
        DragonTile(Dragon.green),
      ]);
      expect(standardShanten(hand), 8);
    });
  });
}
