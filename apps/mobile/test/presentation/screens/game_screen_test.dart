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

  testWidgets('the viewer draws automatically on their own turn, with no manual button', (tester) async {
    final hands = [
      Hand(concealedTiles: filler(pin, 3, 13)),
      Hand(concealedTiles: filler(sou, 3, 13)),
      Hand(concealedTiles: filler(man, 1, 13)),
    ];
    final wall = Wall([pin(9), sou(9), man(9), pin(2), pin(2)]);
    final state = GameState(hands: hands, wall: wall, dealerIndex: 0);

    await tester.pumpWidget(MaterialApp(home: GameScreen(state: state)));

    expect(find.text('ツモ'), findsNothing);
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

  testWidgets('a discard the viewer can pon pauses the game and offers ポン/キャンセル', (tester) async {
    final hands = [
      Hand(concealedTiles: [sou(9), sou(9), ...filler(pin, 3, 11)]), // viewer: pon-ready on 9s.
      Hand(concealedTiles: filler(sou, 3, 13)),
      Hand(concealedTiles: filler(man, 1, 13)),
    ];
    final wall = Wall([sou(9), man(9), ...filler(pin, 1, 10)]);
    final state = GameState(hands: hands, wall: wall, dealerIndex: 1);
    state.drawForCurrentPlayer(); // player1 (CPU) draws 9s...
    state.discard(sou(9)); // ...and discards it: the viewer can now pon.

    await tester.pumpWidget(MaterialApp(home: GameScreen(state: state)));

    expect(find.textContaining('プレイヤー1の捨てた9sをポンできます'), findsOneWidget);
    expect(find.text('ポン'), findsOneWidget);
    expect(find.text('キャンセル'), findsOneWidget);
    // Paused right at the reaction window — player2 hasn't drawn yet.
    expect(state.currentPlayerIndex, 2);
    expect(state.phase, TurnPhase.awaitingDraw);

    await tester.tap(find.text('ポン'));
    await tester.pump();

    expect(state.currentPlayerIndex, 0);
    expect(state.phase, TurnPhase.awaitingDiscard);
    expect(state.hands[0].melds, hasLength(1));
    expect(state.hands[0].concealedTiles, hasLength(11));
  });

  testWidgets('キャンセル declines the pon and resumes play without re-offering it', (tester) async {
    final hands = [
      Hand(concealedTiles: [sou(9), sou(9), ...filler(pin, 3, 11)]),
      Hand(concealedTiles: filler(sou, 3, 13)),
      Hand(concealedTiles: filler(man, 1, 13)),
    ];
    final wall = Wall([sou(9), man(9), ...filler(pin, 1, 10)]);
    final state = GameState(hands: hands, wall: wall, dealerIndex: 1);
    state.drawForCurrentPlayer();
    state.discard(sou(9));

    await tester.pumpWidget(MaterialApp(home: GameScreen(state: state)));
    await tester.tap(find.text('キャンセル'));
    await tester.pump();

    expect(find.text('ポン'), findsNothing);
    expect(find.text('キャンセル'), findsNothing);
    expect(state.hands[0].melds, isEmpty);
    expect(state.discardPiles[1], [sou(9)]); // untouched — no pon was declared.
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
    await tester.tap(find.text('残す'));
    await tester.pump();

    expect(state.phase, TurnPhase.awaitingDiscard);
    expect(state.nukiTiles[0], isEmpty);
    expect(state.currentHand.concealedTiles, contains(const KitaTile()));
    expect(find.text('北'), findsOneWidget);
  });
}
