import 'package:mahjong_engine/mahjong_engine.dart';
import 'package:test/test.dart';

NumberTile man(int n) => NumberTile(NumberSuit.man, n);
NumberTile pin(int n) => NumberTile(NumberSuit.pin, n);
NumberTile sou(int n) => NumberTile(NumberSuit.sou, n);
const kita = KitaTile();

List<Tile> _kokushiComplete() => [
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
    ];

void main() {
  group('isKokushiMusou', () {
    test('true for a complete 14-tile concealed kokushi hand', () {
      final hand = Hand(concealedTiles: _kokushiComplete());
      expect(isKokushiMusou(hand), isTrue);
    });

    test('false at tenpai (only 13 tiles)', () {
      final hand = Hand(
        concealedTiles: _kokushiComplete().sublist(1),
      );
      expect(isKokushiMusou(hand), isFalse);
    });

    test('false with a meld, even a valid-looking tile count', () {
      final hand = Hand(
        concealedTiles: List.generate(11, (_) => man(1)),
        melds: [Meld.kotsu([pin(5), pin(5), pin(5)], source: CallSource.pon)],
      );
      expect(isKokushiMusou(hand), isFalse);
    });
  });

  group('chiitoitsuVariant', () {
    Tile pairPin(int n) => pin(n);

    test('standard: 7 distinct pairs', () {
      final hand = Hand(concealedTiles: [
        for (var n = 1; n <= 7; n++) ...[pairPin(n), pairPin(n)],
      ]);
      expect(chiitoitsuVariant(hand), ClosedFormYaku.chiitoitsu);
    });

    test('4-mai: one kind held as a bare quad, 5 other pairs', () {
      final hand = Hand(concealedTiles: [
        pin(1), pin(1), pin(1), pin(1), // the 4-mai kind
        for (var n = 2; n <= 6; n++) ...[pairPin(n), pairPin(n)],
      ]);
      expect(chiitoitsuVariant(hand), ClosedFormYaku.chiitoitsuYonmai);
    });

    test('8-mai: two kinds held as bare quads, 3 other pairs', () {
      final hand = Hand(concealedTiles: [
        pin(1), pin(1), pin(1), pin(1),
        pin(2), pin(2), pin(2), pin(2),
        pairPin(3), pairPin(3),
        pairPin(4), pairPin(4),
        pairPin(5), pairPin(5),
      ]);
      expect(chiitoitsuVariant(hand), ClosedFormYaku.chiitoitsuHachimai);
    });

    test('null when a kind is held 3 times (not a pair or a bare quad)', () {
      final hand = Hand(concealedTiles: [
        pin(1), pin(1), pin(1),
        for (var n = 2; n <= 7; n++) ...[pairPin(n), pairPin(n)],
      ].sublist(0, 14));
      expect(chiitoitsuVariant(hand), isNull);
    });

    test('null when 北 tiles are present, even if paired', () {
      final hand = Hand(concealedTiles: [
        kita, kita,
        for (var n = 1; n <= 6; n++) ...[pairPin(n), pairPin(n)],
      ]);
      expect(chiitoitsuVariant(hand), isNull);
    });

    test('null with a meld — ankan breaks the shape (STEP5)', () {
      final hand = Hand(
        concealedTiles: [
          for (var n = 1; n <= 5; n++) ...[pairPin(n), pairPin(n)],
        ],
        melds: [Meld.kantsu(List.generate(4, (_) => pin(6)), source: CallSource.ankan)],
      );
      expect(chiitoitsuVariant(hand), isNull);
    });

    test('null at 13 tiles (not yet complete)', () {
      final hand = Hand(concealedTiles: [
        for (var n = 1; n <= 6; n++) ...[pairPin(n), pairPin(n)],
        pin(7),
      ]);
      expect(chiitoitsuVariant(hand), isNull);
    });
  });

  group('detectClosedFormYaku', () {
    test('reports kokushi for a complete kokushi hand', () {
      final hand = Hand(concealedTiles: _kokushiComplete());
      expect(detectClosedFormYaku(hand), [ClosedFormYaku.kokushiMusou]);
    });

    test('reports chiitoitsu for a complete standard chiitoitsu hand', () {
      final hand = Hand(concealedTiles: [
        for (var n = 1; n <= 7; n++) ...[pin(n), pin(n)],
      ]);
      expect(detectClosedFormYaku(hand), [ClosedFormYaku.chiitoitsu]);
    });

    test('empty for a hand that completes neither shape', () {
      final hand = Hand(concealedTiles: [
        for (var n = 1; n <= 6; n++) pin(n),
        for (var n = 1; n <= 6; n++) sou(n),
        pin(7),
        pin(8),
      ]);
      expect(detectClosedFormYaku(hand), isEmpty);
    });
  });
}
