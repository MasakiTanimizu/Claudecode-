import 'package:mahjong_engine/mahjong_engine.dart';
import 'package:test/test.dart';

NumberTile man(int n) => NumberTile(NumberSuit.man, n);
NumberTile pin(int n) => NumberTile(NumberSuit.pin, n);
NumberTile sou(int n) => NumberTile(NumberSuit.sou, n);
DragonTile white() => DragonTile(Dragon.white);
DragonTile green() => DragonTile(Dragon.green);
const east = WindTile(Wind.east);

List<Tile> triple(Tile tile) => [tile, tile, tile];
List<Tile> pair(Tile tile) => [tile, tile];

void main() {
  group('calculateStandardFu', () {
    test('all-sequence menzen ron: base 20 + menzen-ron 10, rounds to 30', () {
      final hand = Hand(concealedTiles: [
        pin(2), pin(3), pin(4),
        pin(5), pin(6), pin(7),
        sou(2), sou(3), sou(4),
        sou(5), sou(6), sou(7),
        sou(8), sou(8),
      ]);
      final result = selectBestStandardHand(hand)!;
      final fu = calculateStandardFu(
        decomposition: result.decomposition,
        isMenzen: hand.isMenzen,
        method: WinMethod.ron,
      );
      expect(fu, 30); // 20 + 10, already a multiple of 10.
    });

    test('open pon (simple) + 3 concealed terminal/honor triplets + dragon pair, tsumo', () {
      final hand = Hand(
        concealedTiles: [
          ...triple(pin(1)),
          ...triple(sou(9)),
          ...triple(pin(9)),
          ...pair(green()),
        ],
        melds: [Meld.kotsu(triple(pin(5)), source: CallSource.pon)],
      );
      final result = selectBestStandardHand(hand)!;
      final fu = calculateStandardFu(
        decomposition: result.decomposition,
        isMenzen: hand.isMenzen,
        method: WinMethod.tsumo,
      );
      // 20 base + 2 tsumo + open simple pon(2) + 3 concealed terminal
      // triplets(8 each = 24) + dragon pair(2) = 50, already round.
      expect(fu, 50);
    });
  });

  group('calculateStandardWinPoints', () {
    test('tanyao-only hand (1翻) uses the fixed low-han table regardless of fu', () {
      final hand = Hand(concealedTiles: [
        pin(2), pin(3), pin(4),
        pin(5), pin(6), pin(7),
        sou(2), sou(3), sou(4),
        sou(5), sou(6), sou(7),
        sou(8), sou(8),
      ]);
      final points = calculateStandardWinPoints(
        hand: hand,
        winnerIsDealer: false,
        method: WinMethod.ron,
      );
      expect(
        points,
        const WinPoints(ronPayment: 1000, tsumoDoubleShare: 1000, tsumoSingleShare: 1000),
      );
    });

    test('yakuman hand uses the 8000 base regardless of fu', () {
      final hand = Hand(concealedTiles: [
        ...triple(white()),
        ...triple(green()),
        ...triple(DragonTile(Dragon.red)),
        pin(3), pin(4), pin(5),
        ...pair(pin(2)),
      ]);
      final points = calculateStandardWinPoints(
        hand: hand,
        winnerIsDealer: false,
        method: WinMethod.ron,
      );
      expect(
        points,
        const WinPoints(ronPayment: 32000, tsumoDoubleShare: 16000, tsumoSingleShare: 8000),
      );
    });

    test('double yakuman (suuankou + tsuiisou) doubles the base', () {
      final hand = Hand(concealedTiles: [
        ...triple(east),
        ...triple(const WindTile(Wind.south)),
        ...triple(const WindTile(Wind.west)),
        ...triple(white()),
        ...pair(green()),
      ]);
      final points = calculateStandardWinPoints(
        hand: hand,
        winnerIsDealer: true,
        method: WinMethod.ron,
      );
      // base 8000*2=16000; dealer ron = *6 = 96000.
      expect(points.ronPayment, 96000);
    });

    test('throws for a hand with no detectable standard yaku', () {
      final hand = Hand(concealedTiles: [
        pin(1), pin(4), pin(7),
        sou(1), sou(4), sou(7),
        man(1), man(9),
        east,
        const WindTile(Wind.south),
        const WindTile(Wind.west),
        white(),
        green(),
      ]);
      expect(
        () => calculateStandardWinPoints(hand: hand, winnerIsDealer: false, method: WinMethod.ron),
        throwsArgumentError,
      );
    });
  });

  group('calculateWinPoints', () {
    test('routes a chiitoitsu hand to the closed-form calculation', () {
      final hand = Hand(concealedTiles: [
        for (var n = 1; n <= 7; n++) ...[pin(n), pin(n)],
      ]);
      final points = calculateWinPoints(hand: hand, winnerIsDealer: false, method: WinMethod.ron);
      expect(
        points,
        const WinPoints(ronPayment: 2000, tsumoDoubleShare: 1000, tsumoSingleShare: 1000),
      );
    });

    test('routes a standard hand to the standard-hand calculation', () {
      final hand = Hand(concealedTiles: [
        pin(2), pin(3), pin(4),
        pin(5), pin(6), pin(7),
        sou(2), sou(3), sou(4),
        sou(5), sou(6), sou(7),
        sou(8), sou(8),
      ]);
      final points = calculateWinPoints(hand: hand, winnerIsDealer: false, method: WinMethod.ron);
      expect(
        points,
        const WinPoints(ronPayment: 1000, tsumoDoubleShare: 1000, tsumoSingleShare: 1000),
      );
    });
  });
}
