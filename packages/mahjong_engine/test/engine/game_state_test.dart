import 'dart:math';

import 'package:mahjong_engine/mahjong_engine.dart';
import 'package:test/test.dart';

NumberTile pin(int n) => NumberTile(NumberSuit.pin, n);
NumberTile sou(int n) => NumberTile(NumberSuit.sou, n);
NumberTile man(int n) => NumberTile(NumberSuit.man, n);

List<Tile> filler(NumberTile Function(int) suit, int rank, int count) =>
    List.generate(count, (_) => suit(rank));

List<Tile> run(NumberTile Function(int) suit, int start) =>
    [suit(start), suit(start + 1), suit(start + 2)];

void main() {
  group('GameState turn loop', () {
    test('draw then discard cycles through all players in order', () {
      final hands = [
        Hand(concealedTiles: filler(pin, 3, 13)),
        Hand(concealedTiles: filler(sou, 3, 13)),
        Hand(concealedTiles: filler(man, 1, 13)),
      ];
      final wall = Wall([pin(9), sou(9), man(9), pin(1), pin(1)]);
      final state = GameState(hands: hands, wall: wall, dealerIndex: 0);

      expect(state.currentPlayerIndex, 0);
      expect(state.phase, TurnPhase.awaitingDraw);

      state.drawForCurrentPlayer();
      expect(state.phase, TurnPhase.awaitingDiscard);
      expect(state.currentHand.concealedTiles, hasLength(14));

      state.discard(pin(9));
      expect(state.phase, TurnPhase.awaitingDraw);
      expect(state.currentPlayerIndex, 1);
      expect(state.discardPiles[0], [pin(9)]);
      expect(state.hands[0].concealedTiles, hasLength(13));

      state.drawForCurrentPlayer();
      state.discard(sou(9));
      expect(state.currentPlayerIndex, 2);

      state.drawForCurrentPlayer();
      state.discard(man(9));
      expect(state.currentPlayerIndex, 0);
    });

    test('exhaustive draw when the wall runs out', () {
      final hands = List.generate(3, (_) => Hand(concealedTiles: filler(pin, 3, 13)));
      // 5 tiles - 2 reserved dora indicators = 3 live draws before exhaustion.
      final wall = Wall([pin(1), pin(2), pin(4), pin(5), pin(6)]);
      final state = GameState(hands: hands, wall: wall, dealerIndex: 0);

      for (var i = 0; i < 3; i++) {
        state.drawForCurrentPlayer();
        expect(state.isOver, isFalse);
        state.discard(state.currentHand.concealedTiles.last);
      }

      state.drawForCurrentPlayer();
      expect(state.isOver, isTrue);
      expect(state.result!.reason, RoundOverReason.exhaustiveDraw);
    });
  });

  group('GameState tsumo', () {
    test('declareTsumo succeeds on a complete chiitoitsu hand', () {
      final tenpaiHand = Hand(concealedTiles: [
        for (var n = 1; n <= 6; n++) ...[pin(n), pin(n)],
        pin(7),
      ]);
      final hands = [
        tenpaiHand,
        Hand(concealedTiles: filler(sou, 3, 13)),
        Hand(concealedTiles: filler(man, 1, 13)),
      ];
      final wall = Wall([pin(7), pin(2), pin(2)]);
      final state = GameState(hands: hands, wall: wall, dealerIndex: 0);

      state.drawForCurrentPlayer();
      expect(state.canDeclareTsumo(), isTrue);

      state.declareTsumo();
      expect(state.isOver, isTrue);
      expect(state.result!.reason, RoundOverReason.tsumo);
      expect(state.result!.winnerIndex, 0);
    });

    test('declareTsumo throws when the hand is not actually complete', () {
      final hands = List.generate(3, (_) => Hand(concealedTiles: filler(pin, 3, 13)));
      final wall = Wall([man(9), pin(2), pin(2)]);
      final state = GameState(hands: hands, wall: wall, dealerIndex: 0);

      state.drawForCurrentPlayer();
      expect(state.canDeclareTsumo(), isFalse);
      expect(state.declareTsumo, throwsStateError);
    });
  });

  group('GameState riichi', () {
    test('declareRiichiAndDiscard locks the hand to tsumogiri afterward', () {
      final riichiReadyHand = Hand(concealedTiles: [
        ...run(pin, 1),
        ...run(pin, 4),
        ...run(pin, 7),
        DragonTile(Dragon.white),
        DragonTile(Dragon.white),
        sou(4),
        sou(5),
      ]);
      final hands = [
        riichiReadyHand,
        Hand(concealedTiles: filler(sou, 3, 13)),
        Hand(concealedTiles: filler(man, 1, 13)),
      ];
      // p0 draws man(9) (junk) then riichi-discards it; p1 draws pin(9),
      // p2 draws sou(9), then p0 draws man(1) and must tsumogiri it.
      final wall = Wall([man(9), pin(9), sou(9), man(1), pin(2), pin(2)]);
      final state = GameState(hands: hands, wall: wall, dealerIndex: 0);

      state.drawForCurrentPlayer();
      state.declareRiichiAndDiscard(man(9));
      expect(state.riichiDeclared, contains(0));
      expect(state.currentPlayerIndex, 1);

      state.drawForCurrentPlayer();
      state.discard(state.currentHand.concealedTiles.last); // p1 tsumogiri
      state.drawForCurrentPlayer();
      state.discard(state.currentHand.concealedTiles.last); // p2 tsumogiri

      state.drawForCurrentPlayer(); // p0 draws man(1)
      expect(() => state.discard(pin(1)), throwsStateError);
      state.discard(man(1)); // only the drawn tile is legal.
      expect(state.currentPlayerIndex, 1);
    });

    test('declareRiichiAndDiscard rejects a discard that leaves the hand not tenpai', () {
      // 13 fully isolated, non-adjacent tiles: shanten 8, nowhere near tenpai
      // (same worst-case shape as standard_shanten_test.dart).
      final farHand = Hand(concealedTiles: [
        pin(1), pin(4), pin(7),
        sou(1), sou(4), sou(7),
        man(1), man(9),
        const WindTile(Wind.east),
        const WindTile(Wind.south),
        const WindTile(Wind.west),
        DragonTile(Dragon.white),
        DragonTile(Dragon.green),
      ]);
      final hands = [
        farHand,
        Hand(concealedTiles: filler(sou, 3, 13)),
        Hand(concealedTiles: filler(man, 9, 13)),
      ];
      final wall = Wall([pin(2), pin(5), pin(5)]);
      final state = GameState(hands: hands, wall: wall, dealerIndex: 0);

      state.drawForCurrentPlayer();
      expect(() => state.declareRiichiAndDiscard(pin(2)), throwsStateError);
    });
  });

  group('GameState ron', () {
    test('another player can declare ron on the tile just discarded', () {
      final chiitoitsuTenpai = Hand(concealedTiles: [
        for (var n = 1; n <= 6; n++) ...[pin(n), pin(n)],
        pin(7),
      ]);
      final hands = [
        chiitoitsuTenpai,
        Hand(concealedTiles: filler(pin, 3, 13)),
        Hand(concealedTiles: filler(sou, 3, 13)),
      ];
      final wall = Wall([pin(7), pin(2), pin(2)]);
      final state = GameState(hands: hands, wall: wall, dealerIndex: 1);

      state.drawForCurrentPlayer(); // p1 draws pin(7)
      state.discard(pin(7)); // p1 discards it straight back out.

      expect(state.canDeclareRon(0), isTrue);
      expect(state.canDeclareRon(2), isFalse);

      state.declareRon(0);
      expect(state.isOver, isTrue);
      expect(state.result!.reason, RoundOverReason.ron);
      expect(state.result!.winnerIndex, 0);
      expect(state.result!.dealtInIndex, 1);
    });
  });

  group('GameState pon', () {
    test('another player can pon the tile just discarded, jumping the turn order', () {
      final hands = [
        Hand(concealedTiles: filler(pin, 3, 13)),
        Hand(concealedTiles: [pin(5), pin(5), ...filler(sou, 3, 11)]),
        Hand(concealedTiles: filler(man, 1, 13)),
      ];
      final wall = Wall([pin(5), pin(2), pin(2)]);
      final state = GameState(hands: hands, wall: wall, dealerIndex: 0);

      state.drawForCurrentPlayer(); // p0 draws pin(5)
      state.discard(pin(5));

      expect(state.canDeclarePon(0), isFalse); // can't pon your own discard.
      expect(state.canDeclarePon(1), isTrue);
      expect(state.canDeclarePon(2), isFalse);

      state.declarePon(1);
      expect(state.currentPlayerIndex, 1);
      expect(state.phase, TurnPhase.awaitingDiscard);
      expect(state.hands[1].concealedTiles, hasLength(11));
      expect(state.hands[1].melds, hasLength(1));
      expect(state.hands[1].melds.single.isOpen, isTrue);
      expect(state.hands[1].melds.single.kind, MeldKind.kotsu);

      // The caller now owes a discard; turn order continues from them.
      state.discard(sou(3));
      expect(state.currentPlayerIndex, 2);
    });

    test('a riichi hand can never pon', () {
      final hands = [
        Hand(concealedTiles: filler(pin, 3, 13)),
        Hand(concealedTiles: [pin(5), pin(5), ...filler(sou, 3, 11)]),
        Hand(concealedTiles: filler(man, 1, 13)),
      ];
      final wall = Wall([pin(5), pin(2), pin(2)]);
      final state = GameState(hands: hands, wall: wall, dealerIndex: 0);
      state.riichiDeclared.add(1);

      state.drawForCurrentPlayer();
      state.discard(pin(5));

      expect(state.canDeclarePon(1), isFalse);
      expect(() => state.declarePon(1), throwsStateError);
    });
  });

  group('GameState.deal', () {
    test('deals a fresh, ready-to-play round', () {
      final fullSet = buildFullTileSet(markPreset: DoraMarkPreset.allRed);
      final state = GameState.deal(
        fullTileSet: fullSet,
        playerCount: 3,
        random: Random(1),
        dealerIndex: 2,
      );

      expect(state.hands, hasLength(3));
      for (final hand in state.hands) {
        expect(hand.concealedTiles, hasLength(13));
      }
      expect(state.wall.tiles, hasLength(totalTileCount - 3 * 13));
      expect(state.currentPlayerIndex, 2);
      expect(state.phase, TurnPhase.awaitingDraw);
    });
  });
}
