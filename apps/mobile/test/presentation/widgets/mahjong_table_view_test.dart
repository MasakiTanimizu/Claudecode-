import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_engine/mahjong_engine.dart';
import 'package:sanma_mobile/presentation/widgets/mahjong_table_view.dart';
import 'package:sanma_mobile/presentation/widgets/tile_view.dart';
import 'package:shared_protocol/shared_protocol.dart';

NumberTile pin(int n) => NumberTile(NumberSuit.pin, n);
NumberTile sou(int n) => NumberTile(NumberSuit.sou, n);
NumberTile man(int n) => NumberTile(NumberSuit.man, n);

List<Tile> filler(NumberTile Function(int) suit, int rank, int count) =>
    List.generate(count, (_) => suit(rank));

void main() {
  testWidgets('lays out every player\'s river around the table without overflowing', (tester) async {
    final hands = [
      Hand(concealedTiles: filler(pin, 3, 13)),
      Hand(concealedTiles: filler(sou, 3, 13)),
      Hand(concealedTiles: filler(man, 1, 13)),
    ];
    final wall = Wall([pin(9), sou(9), man(9), pin(2), pin(2)]);
    final state = GameState(hands: hands, wall: wall, dealerIndex: 0);
    state.drawForCurrentPlayer();
    state.discard(pin(9));
    state.drawForCurrentPlayer();
    state.discard(sou(9));

    final view = buildPlayerView(state, viewerIndex: 0);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MahjongTableView(view: view, wallRemaining: state.wall.remainingLiveCount)),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('プレイヤー0（親）'), findsOneWidget);
    expect(find.text('プレイヤー1'), findsOneWidget);
    expect(find.text('プレイヤー2'), findsOneWidget);
    expect(find.byType(TileView), findsNWidgets(2)); // p0's 9p river tile, p1's 9s river tile.
  });

  testWidgets('marks the current player\'s seat and a riichi declaration', (tester) async {
    final riichiReadyHand = Hand(concealedTiles: [
      pin(1), pin(2), pin(3),
      pin(4), pin(5), pin(6),
      pin(7), pin(8), pin(9),
      DragonTile(Dragon.white), DragonTile(Dragon.white),
      sou(4), sou(5),
    ]);
    final hands = [
      riichiReadyHand,
      Hand(concealedTiles: filler(sou, 3, 13)),
      Hand(concealedTiles: filler(man, 1, 13)),
    ];
    final wall = Wall([man(9), pin(2), pin(2)]);
    final state = GameState(hands: hands, wall: wall, dealerIndex: 0);
    state.drawForCurrentPlayer();
    state.declareRiichiAndDiscard(man(9));

    final view = buildPlayerView(state, viewerIndex: 2);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MahjongTableView(view: view, wallRemaining: state.wall.remainingLiveCount)),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.textContaining('立直'), findsOneWidget);
  });

  testWidgets('shows a player\'s nuku\'d hana as a small badge next to their seat, plus wall/dora info', (tester) async {
    final hands = [
      Hand(concealedTiles: filler(pin, 3, 13)),
      Hand(concealedTiles: filler(sou, 3, 13)),
      Hand(concealedTiles: filler(man, 1, 13)),
    ];
    final wall = Wall([const HanaTile(HanaKind.spring), pin(2), pin(2)]);
    final state = GameState(hands: hands, wall: wall, dealerIndex: 0);
    state.drawForCurrentPlayer(); // auto-nuku's the spring hana.

    final view = buildPlayerView(state, viewerIndex: 0);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MahjongTableView(view: view, wallRemaining: state.wall.remainingLiveCount)),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('春'), findsOneWidget);
    expect(find.textContaining('山: ${state.wall.remainingLiveCount}枚'), findsOneWidget);
  });

  testWidgets('shows running scores per seat and the round label when a match is passed in', (tester) async {
    final hands = [
      Hand(concealedTiles: filler(pin, 3, 13)),
      Hand(concealedTiles: filler(sou, 3, 13)),
      Hand(concealedTiles: filler(man, 1, 13)),
    ];
    final wall = Wall([pin(2), pin(3), pin(4)]);
    final state = GameState(hands: hands, wall: wall, dealerIndex: 0);
    final view = buildPlayerView(state, viewerIndex: 0);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MahjongTableView(
            view: view,
            wallRemaining: state.wall.remainingLiveCount,
            scores: const [36000, 34000, 35000],
            roundLabel: '東1局',
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.textContaining('プレイヤー0（親） 36000点'), findsOneWidget);
    expect(find.textContaining('プレイヤー1 34000点'), findsOneWidget);
    expect(find.textContaining('プレイヤー2 35000点'), findsOneWidget);
    expect(find.text('東1局'), findsOneWidget);
  });
}
