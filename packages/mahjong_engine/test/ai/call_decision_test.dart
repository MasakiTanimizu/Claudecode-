import 'package:mahjong_engine/mahjong_engine.dart';
import 'package:test/test.dart';

NumberTile man(int n) => NumberTile(NumberSuit.man, n);
NumberTile pin(int n) => NumberTile(NumberSuit.pin, n);
NumberTile sou(int n) => NumberTile(NumberSuit.sou, n);

void main() {
  group('shouldCall', () {
    test('初級 never calls, even when it would clearly help', () {
      final handBeforeCall = Hand(concealedTiles: [
        DragonTile(Dragon.white), DragonTile(Dragon.white),
        pin(1), pin(3), pin(5), pin(7), pin(9),
        sou(1), sou(3), sou(5), sou(7), sou(9),
        man(1),
      ]);
      final handAfterCall = Hand(
        concealedTiles: [
          pin(1), pin(3), pin(5), pin(7), pin(9),
          sou(1), sou(3), sou(5), sou(7), sou(9),
          man(1),
        ],
        melds: [
          Meld.kotsu([DragonTile(Dragon.white), DragonTile(Dragon.white), DragonTile(Dragon.white)],
              source: CallSource.pon),
        ],
      );

      expect(shouldCall(handBeforeCall, handAfterCall, CpuDifficulty.beginner), isFalse);
    });

    test('中級/上級 call when it turns an isolated pair into a real group', () {
      final handBeforeCall = Hand(concealedTiles: [
        DragonTile(Dragon.white), DragonTile(Dragon.white),
        pin(1), pin(3), pin(5), pin(7), pin(9),
        sou(1), sou(3), sou(5), sou(7), sou(9),
        man(1),
      ]);
      final handAfterCall = Hand(
        concealedTiles: [
          pin(1), pin(3), pin(5), pin(7), pin(9),
          sou(1), sou(3), sou(5), sou(7), sou(9),
          man(1),
        ],
        melds: [
          Meld.kotsu([DragonTile(Dragon.white), DragonTile(Dragon.white), DragonTile(Dragon.white)],
              source: CallSource.pon),
        ],
      );

      expect(shouldCall(handBeforeCall, handAfterCall, CpuDifficulty.intermediate), isTrue);
      expect(shouldCall(handBeforeCall, handAfterCall, CpuDifficulty.advanced), isTrue);
    });

    test('中級/上級 decline when calling would break the hand\'s only pair', () {
      // Tenpai as-is (waiting on 3s/6s) with man(1) pair as the head — pon-ing
      // a third man(1) uses up that pair, leaving no pair anywhere else in
      // the hand, which makes shanten worse instead of better.
      final handBeforeCall = Hand(concealedTiles: [
        man(1), man(1),
        pin(1), pin(2), pin(3),
        pin(4), pin(5), pin(6),
        sou(1), sou(2), sou(3),
        sou(4), sou(5),
      ]);
      final handAfterCall = Hand(
        concealedTiles: [
          pin(1), pin(2), pin(3),
          pin(4), pin(5), pin(6),
          sou(1), sou(2), sou(3),
          sou(4), sou(5),
        ],
        melds: [
          Meld.kotsu([man(1), man(1), man(1)], source: CallSource.pon),
        ],
      );

      expect(overallShanten(handBeforeCall), 0);
      expect(overallShanten(handAfterCall), greaterThan(0));
      expect(shouldCall(handBeforeCall, handAfterCall, CpuDifficulty.intermediate), isFalse);
      expect(shouldCall(handBeforeCall, handAfterCall, CpuDifficulty.advanced), isFalse);
    });
  });
}
