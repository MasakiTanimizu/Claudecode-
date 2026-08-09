import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_engine/mahjong_engine.dart';
import 'package:sanma_mobile/presentation/screens/game_screen.dart';
import 'package:sanma_mobile/presentation/widgets/tile_view.dart';

NumberTile pin(int n) => NumberTile(NumberSuit.pin, n);
NumberTile sou(int n) => NumberTile(NumberSuit.sou, n);
NumberTile man(int n) => NumberTile(NumberSuit.man, n);

List<Tile> filler(NumberTile Function(int) suit, int rank, int count) =>
    List.generate(count, (_) => suit(rank));

void main() {
  testWidgets('shows the viewer\'s own hand, discard piles, and dora indicators', (tester) async {
    final hands = [
      Hand(concealedTiles: filler(pin, 3, 13)),
      Hand(concealedTiles: filler(sou, 3, 13)),
      Hand(concealedTiles: filler(man, 1, 13)),
    ];
    final wall = Wall([pin(9), pin(2), pin(2)]);
    final state = GameState(hands: hands, wall: wall, dealerIndex: 0);
    state.drawForCurrentPlayer();
    state.discard(pin(9));

    await tester.pumpWidget(MaterialApp(home: GameScreen(state: state)));

    expect(find.text('自分の手牌'), findsOneWidget);
    expect(find.byType(TileView), findsWidgets);
    expect(find.textContaining('手番: プレイヤー1'), findsOneWidget);
    expect(find.textContaining('プレイヤー0（親）'), findsOneWidget);
  });

  testWidgets('the draw button lets the viewer draw on their own turn', (tester) async {
    final hands = [
      Hand(concealedTiles: filler(pin, 3, 13)),
      Hand(concealedTiles: filler(sou, 3, 13)),
      Hand(concealedTiles: filler(man, 1, 13)),
    ];
    final wall = Wall([pin(9), sou(9), man(9), pin(2), pin(2)]);
    final state = GameState(hands: hands, wall: wall, dealerIndex: 0);

    await tester.pumpWidget(MaterialApp(home: GameScreen(state: state)));

    expect(find.text('ツモ'), findsOneWidget);
    await tester.tap(find.text('ツモ'));
    await tester.pump();

    expect(state.phase, TurnPhase.awaitingDiscard);
    expect(state.hands[0].concealedTiles, hasLength(14));
  });

  testWidgets('double-tapping a tile discards it, then the CPUs play their turns', (tester) async {
    final hands = [
      Hand(concealedTiles: filler(pin, 3, 13)),
      Hand(concealedTiles: filler(sou, 3, 13)),
      Hand(concealedTiles: filler(man, 1, 13)),
    ];
    final wall = Wall([pin(9), sou(9), man(9), pin(2), pin(2), pin(2)]);
    final state = GameState(hands: hands, wall: wall, dealerIndex: 0);
    state.drawForCurrentPlayer(); // the viewer has already drawn 9p.

    await tester.pumpWidget(MaterialApp(home: GameScreen(state: state)));

    await tester.tap(find.text('9p'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('9p'));
    await tester.pump();

    expect(state.currentPlayerIndex, 0); // back to the viewer after CPUs 1 and 2 acted.
    expect(state.discardPiles[1], hasLength(1));
    expect(state.discardPiles[2], hasLength(1));
    // Flush the gesture recognizer's own internal timer so the test
    // framework doesn't see it as still pending at teardown.
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('the tsumo button appears and ends the round on a winning hand', (tester) async {
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

    await tester.pumpWidget(MaterialApp(home: GameScreen(state: state)));
    await tester.tap(find.text('ツモ'));
    await tester.pump();

    expect(find.text('和了'), findsOneWidget);
    await tester.tap(find.text('和了'));
    await tester.pump();

    expect(state.isOver, isTrue);
    expect(find.textContaining('ツモ和了'), findsOneWidget);
  });

  testWidgets('drawing a kita shows the nuku/keep choice, and 抜く draws a replacement', (tester) async {
    final hands = [
      Hand(concealedTiles: filler(pin, 3, 13)),
      Hand(concealedTiles: filler(sou, 3, 13)),
      Hand(concealedTiles: filler(man, 1, 13)),
    ];
    final wall = Wall([const KitaTile(), pin(9), pin(2), pin(2)]);
    final state = GameState(hands: hands, wall: wall, dealerIndex: 0);

    await tester.pumpWidget(MaterialApp(home: GameScreen(state: state)));
    await tester.tap(find.text('ツモ'));
    await tester.pump();

    expect(find.textContaining('北を引きました'), findsOneWidget);
    expect(find.text('抜く'), findsOneWidget);
    expect(find.text('残す'), findsOneWidget);
    expect(state.phase, TurnPhase.awaitingKitaDecision);

    await tester.tap(find.text('抜く'));
    await tester.pump();

    expect(state.phase, TurnPhase.awaitingDiscard);
    expect(state.nukiTiles[0], [const KitaTile()]);
    expect(find.text('9p'), findsOneWidget);
  });

  testWidgets('drawing a kita and choosing 残す keeps it in the hand', (tester) async {
    final hands = [
      Hand(concealedTiles: filler(pin, 3, 13)),
      Hand(concealedTiles: filler(sou, 3, 13)),
      Hand(concealedTiles: filler(man, 1, 13)),
    ];
    final wall = Wall([const KitaTile(), pin(2), pin(2)]);
    final state = GameState(hands: hands, wall: wall, dealerIndex: 0);

    await tester.pumpWidget(MaterialApp(home: GameScreen(state: state)));
    await tester.tap(find.text('ツモ'));
    await tester.pump();
    await tester.tap(find.text('残す'));
    await tester.pump();

    expect(state.phase, TurnPhase.awaitingDiscard);
    expect(state.nukiTiles[0], isEmpty);
    expect(state.currentHand.concealedTiles, contains(const KitaTile()));
    expect(find.text('北'), findsOneWidget);
  });
}
