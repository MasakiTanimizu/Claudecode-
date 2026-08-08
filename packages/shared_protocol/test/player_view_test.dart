import 'package:mahjong_engine/mahjong_engine.dart';
import 'package:shared_protocol/shared_protocol.dart';
import 'package:test/test.dart';

NumberTile pin(int n) => NumberTile(NumberSuit.pin, n);
NumberTile sou(int n) => NumberTile(NumberSuit.sou, n);
NumberTile man(int n) => NumberTile(NumberSuit.man, n);

List<Tile> filler(NumberTile Function(int) suit, int rank, int count) =>
    List.generate(count, (_) => suit(rank));

void main() {
  group('buildPlayerView', () {
    test('reveals the viewer\'s own hand but only tile counts for others', () {
      final hands = [
        Hand(concealedTiles: filler(pin, 3, 13)),
        Hand(concealedTiles: filler(sou, 3, 13)),
        Hand(concealedTiles: filler(man, 1, 13)),
      ];
      final wall = Wall([pin(9), pin(2), pin(2)]);
      final state = GameState(hands: hands, wall: wall, dealerIndex: 0);

      final view = buildPlayerView(state, viewerIndex: 0);

      expect(view.viewerIndex, 0);
      expect(view.ownConcealedTiles, hands[0].concealedTiles);
      expect(view.concealedTileCounts, [13, 13, 13]);
      expect(view.dealerIndex, 0);
      expect(view.currentPlayerIndex, 0);
      expect(view.phase, TurnPhase.awaitingDraw);
      expect(view.riichiPlayers, isEmpty);
      expect(view.result, isNull);
    });

    test('open melds are public for every player, including non-viewers', () {
      final hands = [
        Hand(
          concealedTiles: filler(pin, 3, 10),
          melds: [
            Meld.kotsu([sou(7), sou(7), sou(7)], source: CallSource.pon),
          ],
        ),
        Hand(concealedTiles: filler(sou, 3, 13)),
        Hand(concealedTiles: filler(man, 1, 13)),
      ];
      final wall = Wall([pin(9), pin(2), pin(2)]);
      final state = GameState(hands: hands, wall: wall, dealerIndex: 0);

      final view = buildPlayerView(state, viewerIndex: 1);

      expect(view.viewerIndex, 1);
      expect(view.ownConcealedTiles, hands[1].concealedTiles);
      expect(view.melds[0], hands[0].melds); // player 0's open pon, visible to player 1.
      expect(view.concealedTileCounts[0], 10);
    });

    test('reflects a riichi declaration and the discard pile', () {
      final hands = [
        Hand(concealedTiles: [
          NumberTile(NumberSuit.pin, 1),
          NumberTile(NumberSuit.pin, 2),
          NumberTile(NumberSuit.pin, 3),
          NumberTile(NumberSuit.pin, 4),
          NumberTile(NumberSuit.pin, 5),
          NumberTile(NumberSuit.pin, 6),
          NumberTile(NumberSuit.pin, 7),
          NumberTile(NumberSuit.pin, 8),
          NumberTile(NumberSuit.pin, 9),
          DragonTile(Dragon.white),
          DragonTile(Dragon.white),
          sou(4),
          sou(5),
        ]),
        Hand(concealedTiles: filler(sou, 3, 13)),
        Hand(concealedTiles: filler(man, 1, 13)),
      ];
      final wall = Wall([man(9), pin(2), pin(2)]);
      final state = GameState(hands: hands, wall: wall, dealerIndex: 0);

      state.drawForCurrentPlayer();
      state.declareRiichiAndDiscard(man(9));

      final view = buildPlayerView(state, viewerIndex: 2);
      expect(view.riichiPlayers, {0});
      expect(view.discardPiles[0], [man(9)]);
    });
  });
}
