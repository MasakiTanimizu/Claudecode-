import 'dart:math';

import 'package:mahjong_engine/mahjong_engine.dart';
import 'package:test/test.dart';

List<Tile> sequentialPinTiles(int count) =>
    List.generate(count, (i) => NumberTile(NumberSuit.pin, (i % 9) + 1));

void main() {
  group('Wall', () {
    test('draw() returns tiles in order and advances the pointer', () {
      final tiles = sequentialPinTiles(10);
      final wall = Wall(tiles);
      expect(wall.draw(), tiles[0]);
      expect(wall.draw(), tiles[1]);
      // 10 tiles - 2 reserved dora indicators - 2 drawn = 6 left.
      expect(wall.remainingLiveCount, 6);
    });

    test('starts with 2 live dora indicators reserved', () {
      final wall = Wall(sequentialPinTiles(10));
      expect(wall.doraIndicators, hasLength(2));
      expect(wall.remainingLiveCount, 8);
    });

    test('revealNextDoraIndicator adds one indicator and shrinks the live wall by one', () {
      final wall = Wall(sequentialPinTiles(10));
      wall.revealNextDoraIndicator();
      expect(wall.doraIndicators, hasLength(3));
      expect(wall.remainingLiveCount, 7);
    });

    test('a kan/kita/hana replacement draw is just draw() — no separate rinshan pool', () {
      final tiles = sequentialPinTiles(10);
      final wall = Wall(tiles);
      final normalDraw = wall.draw();
      final replacementDraw = wall.draw();
      expect(normalDraw, tiles[0]);
      expect(replacementDraw, tiles[1]);
    });

    test('isExhausted becomes true exactly when the live wall hits zero', () {
      final wall = Wall(sequentialPinTiles(5)); // 5 - 2 reserved = 3 live
      expect(wall.isExhausted, isFalse);
      wall.draw();
      wall.draw();
      expect(wall.isExhausted, isFalse);
      wall.draw();
      expect(wall.remainingLiveCount, 0);
      expect(wall.isExhausted, isTrue);
    });

    test('draw() throws once exhausted (流局)', () {
      final wall = Wall(sequentialPinTiles(3)); // 3 - 2 reserved = 1 live
      wall.draw();
      expect(wall.isExhausted, isTrue);
      expect(wall.draw, throwsStateError);
    });

    test('many kans can exhaust the wall faster than draws alone', () {
      final wall = Wall(sequentialPinTiles(5)); // 3 live to start
      wall.revealNextDoraIndicator(); // 2 live
      wall.revealNextDoraIndicator(); // 1 live
      wall.revealNextDoraIndicator(); // 0 live
      expect(wall.isExhausted, isTrue);
    });
  });

  group('dealHands', () {
    test('deals 13 tiles to each of 3 players and keeps the rest as the wall', () {
      final fullSet = buildFullTileSet(markPreset: DoraMarkPreset.allRed);
      final result = dealHands(fullSet, playerCount: 3, random: Random(42));

      expect(result.hands, hasLength(3));
      for (final hand in result.hands) {
        expect(hand, hasLength(13));
      }
      expect(result.wall.tiles, hasLength(totalTileCount - 3 * 13));
    });

    test('every tile is accounted for exactly once across hands and wall', () {
      final fullSet = buildFullTileSet(markPreset: DoraMarkPreset.oneRedOneBlue);
      final result = dealHands(fullSet, playerCount: 3, random: Random(7));

      final dealt = [...result.hands.expand((h) => h), ...result.wall.tiles];
      expect(dealt, hasLength(totalTileCount));
      // Sanity check via counts rather than object identity: same multiset
      // of tileKinds (+ marks) should appear before and after the shuffle.
      final beforeLabels = fullSet.map((t) => t.label).toList()..sort();
      final afterLabels = dealt.map((t) => t.label).toList()..sort();
      expect(afterLabels, beforeLabels);
    });

    test('throws if the tile set is too small to leave a wall', () {
      final tooFew = sequentialPinTiles(30); // 3*13=39 > 30
      expect(
        () => dealHands(tooFew, playerCount: 3, random: Random(1)),
        throwsArgumentError,
      );
    });
  });
}
