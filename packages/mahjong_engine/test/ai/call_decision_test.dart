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

    test('中級/上級 decline when calling would destroy a much better 七対子 route', () {
      // 6 pairs of otherwise-unconnected terminals/honors plus a lone 7th
      // kind — already tenpai via 七対子 (waiting on the green dragon for
      // the 7th pair). None of these pairs are adjacent ranks (1p/9p,
      // 1s/9s) or the same suit run, so the standard (4 melds + pair) shape
      // is far worse on this same hand. Pon-ing any of the pairs forms an
      // open meld, which chiitoitsu can never allow — falling back to the
      // much worse standard-only shanten makes calling a net loss overall,
      // even though the call itself forms a "valid" group.
      final handBeforeCall = Hand(concealedTiles: [
        pin(1), pin(1), pin(9), pin(9),
        sou(1), sou(1), sou(9), sou(9),
        man(1), man(1),
        DragonTile(Dragon.white), DragonTile(Dragon.white),
        DragonTile(Dragon.green),
      ]);
      final handAfterCall = Hand(
        concealedTiles: [
          pin(9), pin(9),
          sou(1), sou(1), sou(9), sou(9),
          man(1), man(1),
          DragonTile(Dragon.white), DragonTile(Dragon.white),
          DragonTile(Dragon.green),
        ],
        melds: [
          Meld.kotsu([pin(1), pin(1), pin(1)], source: CallSource.pon),
        ],
      );

      expect(overallShanten(handBeforeCall), 0);
      expect(overallShanten(handAfterCall), greaterThan(0));
      expect(shouldCall(handBeforeCall, handAfterCall, CpuDifficulty.intermediate), isFalse);
      expect(shouldCall(handBeforeCall, handAfterCall, CpuDifficulty.advanced), isFalse);
    });
  });
}
