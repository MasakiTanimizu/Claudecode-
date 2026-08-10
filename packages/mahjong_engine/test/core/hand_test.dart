import 'package:mahjong_engine/mahjong_engine.dart';
import 'package:test/test.dart';

NumberTile pin(int n) => NumberTile(NumberSuit.pin, n);

List<Tile> repeat(Tile tile, int count) => List.generate(count, (_) => tile);

void main() {
  group('Hand.isMenzen', () {
    test('true with no melds', () {
      final hand = Hand(concealedTiles: repeat(pin(1), 13));
      expect(hand.isMenzen, isTrue);
    });

    test('true with only ankan', () {
      final hand = Hand(
        concealedTiles: repeat(pin(1), 9),
        melds: [Meld.kantsu(repeat(pin(5), 4), source: CallSource.ankan)],
      );
      expect(hand.isMenzen, isTrue);
    });

    test('false with a pon', () {
      final hand = Hand(
        concealedTiles: repeat(pin(1), 10),
        melds: [Meld.kotsu(repeat(pin(5), 3), source: CallSource.pon)],
      );
      expect(hand.isMenzen, isFalse);
    });
  });

  group('Hand.hasLegalTileCount', () {
    test('13 concealed tiles is legal at rest', () {
      final hand = Hand(concealedTiles: repeat(pin(1), 13));
      expect(hand.hasLegalTileCount(justDrew: false), isTrue);
      expect(hand.hasLegalTileCount(justDrew: true), isFalse);
    });

    test('14 tiles is legal right after a draw', () {
      final hand = Hand(concealedTiles: repeat(pin(1), 14));
      expect(hand.hasLegalTileCount(justDrew: true), isTrue);
      expect(hand.hasLegalTileCount(justDrew: false), isFalse);
    });

    test('one kan raises the legal count by one', () {
      final hand = Hand(
        concealedTiles: repeat(pin(1), 10),
        melds: [Meld.kantsu(repeat(pin(5), 4), source: CallSource.ankan)],
      );
      expect(hand.kanCount, 1);
      expect(hand.hasLegalTileCount(justDrew: false), isTrue);
      expect(hand.hasLegalTileCount(justDrew: true), isFalse);
    });

    test('a short hand is illegal', () {
      final hand = Hand(concealedTiles: repeat(pin(1), 12));
      expect(hand.hasLegalTileCount(justDrew: false), isFalse);
    });
  });

  group('Hand.tileCount', () {
    test('sums concealed tiles and meld tiles', () {
      final hand = Hand(
        concealedTiles: repeat(pin(1), 8),
        melds: [Meld.kotsu(repeat(pin(5), 3), source: CallSource.pon)],
      );
      expect(hand.tileCount, 11);
    });
  });
}
