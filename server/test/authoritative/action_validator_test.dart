import 'package:mahjong_engine/mahjong_engine.dart';
import 'package:sanma_server/server.dart';
import 'package:test/test.dart';

NumberTile man(int n) => NumberTile(NumberSuit.man, n);
NumberTile pin(int n) => NumberTile(NumberSuit.pin, n);
NumberTile sou(int n) => NumberTile(NumberSuit.sou, n);

List<Tile> filler(NumberTile Function(int) suit, int rank, int count) =>
    List.generate(count, (_) => suit(rank));

GameState _freshState({int dealerIndex = 0}) {
  final hands = [
    Hand(concealedTiles: filler(pin, 3, 13)),
    Hand(concealedTiles: filler(sou, 3, 13)),
    Hand(concealedTiles: filler(man, 1, 13)),
  ];
  final wall = Wall([pin(9), sou(9), man(9), pin(2), pin(2)]);
  return GameState(hands: hands, wall: wall, dealerIndex: dealerIndex);
}

void main() {
  group('applyMatchAction — turn ownership', () {
    test('accepts a draw from the actual current player', () {
      final state = _freshState();
      final result = applyMatchAction(state, const DrawAction(0));

      expect(result, isA<MatchActionAccepted>());
      expect(state.phase, TurnPhase.awaitingDiscard);
      expect(state.hands[0].concealedTiles, hasLength(14));
    });

    test('rejects a draw claimed by a player whose turn it is not', () {
      final state = _freshState();
      final result = applyMatchAction(state, const DrawAction(1));

      expect(result, isA<MatchActionRejected>());
      expect((result as MatchActionRejected).reason, contains('out of turn'));
      // Nothing should have been mutated.
      expect(state.phase, TurnPhase.awaitingDraw);
      expect(state.hands[1].concealedTiles, hasLength(13));
    });

    test('rejects a discard claimed by the wrong player', () {
      final state = _freshState();
      applyMatchAction(state, const DrawAction(0));

      final result = applyMatchAction(state, DiscardAction(1, pin(9)));
      expect(result, isA<MatchActionRejected>());
      expect(state.phase, TurnPhase.awaitingDiscard); // unchanged.
    });
  });

  group('applyMatchAction — pass-through GameState validation', () {
    test('rejects a discard of a tile not actually in hand', () {
      final state = _freshState();
      applyMatchAction(state, const DrawAction(0));

      final result = applyMatchAction(state, DiscardAction(0, man(1)));
      expect(result, isA<MatchActionRejected>());
      expect((result as MatchActionRejected).reason, contains('not in the current hand'));
    });

    test('accepts a legal discard from the current player', () {
      final state = _freshState();
      applyMatchAction(state, const DrawAction(0));

      final result = applyMatchAction(state, DiscardAction(0, pin(9)));
      expect(result, isA<MatchActionAccepted>());
      expect(state.currentPlayerIndex, 1);
    });
  });

  group('applyMatchAction — reactions (ron/pon) are not turn-bound', () {
    test('accepts a ron from a non-current player on a winning discard', () {
      final hands = [
        Hand(concealedTiles: [
          for (var n = 1; n <= 6; n++) ...[pin(n), pin(n)],
          pin(7),
        ]),
        Hand(concealedTiles: filler(pin, 3, 13)),
        Hand(concealedTiles: filler(sou, 3, 13)),
      ];
      final wall = Wall([pin(7), pin(2), pin(2)]);
      final state = GameState(hands: hands, wall: wall, dealerIndex: 1);

      applyMatchAction(state, const DrawAction(1));
      applyMatchAction(state, DiscardAction(1, pin(7)));

      final result = applyMatchAction(state, const RonAction(0));
      expect(result, isA<MatchActionAccepted>());
      expect(state.isOver, isTrue);
      expect(state.result!.reason, RoundOverReason.ron);
    });

    test('rejects a ron claim with no eligible winning hand', () {
      final state = _freshState();
      applyMatchAction(state, const DrawAction(0));
      applyMatchAction(state, DiscardAction(0, pin(9)));

      final result = applyMatchAction(state, const RonAction(2));
      expect(result, isA<MatchActionRejected>());
    });

    test('accepts a pon that jumps the turn to the caller', () {
      final hands = [
        Hand(concealedTiles: filler(pin, 3, 13)),
        Hand(concealedTiles: [pin(5), pin(5), ...filler(sou, 3, 11)]),
        Hand(concealedTiles: filler(man, 1, 13)),
      ];
      final wall = Wall([pin(5), pin(2), pin(2)]);
      final state = GameState(hands: hands, wall: wall, dealerIndex: 0);

      applyMatchAction(state, const DrawAction(0));
      applyMatchAction(state, DiscardAction(0, pin(5)));

      final result = applyMatchAction(state, const PonAction(1));
      expect(result, isA<MatchActionAccepted>());
      expect(state.currentPlayerIndex, 1);
      expect(state.phase, TurnPhase.awaitingDiscard);
      expect(state.hands[1].melds, hasLength(1));
    });
  });
}
