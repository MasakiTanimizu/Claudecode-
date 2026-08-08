import 'package:mahjong_engine/mahjong_engine.dart';
import 'package:test/test.dart';

NumberTile man(int n) => NumberTile(NumberSuit.man, n);
NumberTile pin(int n) => NumberTile(NumberSuit.pin, n);
NumberTile sou(int n) => NumberTile(NumberSuit.sou, n);
const kita = KitaTile();

void main() {
  group('kokushiShanten', () {
    test('1-shanten: 12 distinct kinds plus one irrelevant filler tile', () {
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
        pin(5), // irrelevant filler: not a kokushi kind.
      ]);
      expect(kokushiShanten(hand), 1);
    });

    test('tenpai: all 13 kinds present with no duplicate', () {
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
        kita,
      ]);
      expect(kokushiShanten(hand), 0);
    });

    test('complete: 13 kinds plus one duplicate forming the pair', () {
      final hand = Hand(concealedTiles: [
        man(1),
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
        kita,
      ]);
      expect(kokushiShanten(hand), -1);
    });

    test('a hand with any meld is treated as maximally far', () {
      final hand = Hand(
        concealedTiles: List.generate(10, (_) => man(1)),
        melds: [Meld.kotsu([pin(5), pin(5), pin(5)], source: CallSource.pon)],
      );
      expect(kokushiShanten(hand), 13);
    });
  });

  group('chiitoitsuShanten', () {
    test('tenpai: 6 pairs plus one single', () {
      final hand = Hand(concealedTiles: [
        pin(1), pin(1),
        pin(2), pin(2),
        pin(3), pin(3),
        pin(4), pin(4),
        pin(5), pin(5),
        pin(6), pin(6),
        pin(7),
      ]);
      expect(chiitoitsuShanten(hand), 0);
    });

    test('complete: 7 distinct pairs', () {
      final hand = Hand(concealedTiles: [
        pin(1), pin(1),
        pin(2), pin(2),
        pin(3), pin(3),
        pin(4), pin(4),
        pin(5), pin(5),
        pin(6), pin(6),
        pin(7), pin(7),
      ]);
      expect(chiitoitsuShanten(hand), -1);
    });

    test('insufficient variety: extra duplicates beyond a pair do not help', () {
      // Only 3 distinct kinds, each with 4 copies: 3 pairs at best, and the
      // 7-kindCount variety penalty dominates.
      final hand = Hand(concealedTiles: [
        pin(1), pin(1), pin(1), pin(1),
        pin(2), pin(2), pin(2), pin(2),
        pin(3), pin(3), pin(3), pin(3),
        pin(4),
      ]);
      // pairCount=3, kindCount=4 -> 6 - 3 + (7-4) = 6.
      expect(chiitoitsuShanten(hand), 6);
    });

    test('北 tiles never count toward chiitoitsu pairs', () {
      final hand = Hand(concealedTiles: [
        pin(1), pin(1),
        pin(2), pin(2),
        pin(3), pin(3),
        pin(4), pin(4),
        pin(5), pin(5),
        pin(6), pin(6),
        kita, kita,
      ]);
      // Only 6 usable pairs; kindCount among usable kinds is 6.
      expect(chiitoitsuShanten(hand), 1);
    });

    test('a hand with any meld is treated as maximally far', () {
      final hand = Hand(
        concealedTiles: List.generate(10, (_) => pin(1)),
        melds: [Meld.kotsu([pin(5), pin(5), pin(5)], source: CallSource.pon)],
      );
      expect(chiitoitsuShanten(hand), 6);
    });
  });
}
