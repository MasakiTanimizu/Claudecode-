import 'dart:math';

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

  testWidgets('drawing a hana auto-nuku\'s it, never entering the hand', (tester) async {
    final hands = [
      Hand(concealedTiles: filler(pin, 3, 13)),
      Hand(concealedTiles: filler(sou, 3, 13)),
      Hand(concealedTiles: filler(man, 1, 13)),
    ];
    final wall = Wall([const HanaTile(HanaKind.summer), pin(9), pin(2), pin(2)]);
    final state = GameState(hands: hands, wall: wall, dealerIndex: 0);

    await tester.pumpWidget(MaterialApp(home: GameScreen(state: state)));

    expect(state.nukiTiles[0], [const HanaTile(HanaKind.summer)]);
    expect(state.currentHand.concealedTiles, isNot(contains(const HanaTile(HanaKind.summer))));
  });

  testWidgets('a CPU\'s kita decision already pending at mount (e.g. from haipai) resolves silently before the viewer sees it', (tester) async {
    final hands = [
      Hand(concealedTiles: filler(pin, 3, 13)),
      Hand(concealedTiles: filler(sou, 3, 13)),
      Hand(concealedTiles: filler(man, 1, 13)),
    ];
    final wall = Wall([const KitaTile(), pin(9), pin(2), pin(2)]);
    final state = GameState(hands: hands, wall: wall, dealerIndex: 1);
    state.drawForCurrentPlayer(); // player1 (CPU) draws a kita — mimics a haipai pause.
    expect(state.hasPendingKitaDecision, isTrue);
    expect(state.currentPlayerIndex, 1);

    await tester.pumpWidget(MaterialApp(home: GameScreen(state: state)));

    expect(state.hasPendingKitaDecision, isFalse);
    expect(find.text('抜く'), findsNothing);
  });

  testWidgets('resolving the viewer\'s own haipai kita never leaves the game stuck on a CPU\'s pending one', (tester) async {
    // Every tile is a kita, so every player (viewer included) is
    // guaranteed a haipai kita decision — a small, adversarial fixture
    // that reliably exercises GameState's dealer-first, one-player-at-a-
    // time sweep across all 3 seats, including the CPUs' portions
    // GameScreen has to auto-resolve without ever leaving the viewer with
    // nothing to press (regression test: resolving the viewer's own
    // haipai kita used to leave the sweep paused on a CPU's turn with no
    // UI for it and nothing left to move it forward — the game just
    // stopped).
    final fullSet = List.generate(80, (_) => const KitaTile());
    final state = GameState.deal(
      fullTileSet: fullSet,
      playerCount: 3,
      random: Random(0),
      dealerIndex: 0,
    );

    await tester.pumpWidget(MaterialApp(home: GameScreen(state: state)));
    expect(find.text('抜く'), findsOneWidget); // the viewer's own haipai kita.

    for (var guard = 0; guard < 25; guard++) {
      final keepButton = find.text('キャンセル');
      if (keepButton.evaluate().isEmpty) break;
      await tester.tap(keepButton);
      await tester.pump();

      final stuck = !state.isOver && state.currentPlayerIndex != 0;
      expect(
        stuck,
        isFalse,
        reason: 'stuck on player ${state.currentPlayerIndex} (phase ${state.phase}) '
            'with nothing for the viewer to press',
      );
    }

    expect(find.text('抜く'), findsNothing);
    expect(state.phase, TurnPhase.awaitingDiscard);
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

    expect(find.text('抜く'), findsOneWidget);
    expect(find.text('キャンセル'), findsOneWidget);
    expect(state.phase, TurnPhase.awaitingKitaDecision);

    await tester.tap(find.text('抜く'));
    await tester.pump();

    expect(state.phase, TurnPhase.awaitingDiscard);
    expect(state.nukiTiles[0], [const KitaTile()]);
    expect(find.text('9p'), findsOneWidget);
  });

  testWidgets('a discard the viewer can ron on offers ロン and ends the round on tap', (tester) async {
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
    state.drawForCurrentPlayer(); // player1 (CPU) draws 7p...
    state.discard(pin(7)); // ...and discards it: the viewer can now ron.

    await tester.pumpWidget(MaterialApp(home: GameScreen(state: state)));

    expect(find.text('ロン'), findsOneWidget);
    expect(find.text('ポン'), findsNothing);
    expect(find.text('カン'), findsNothing);
    expect(find.text('キャンセル'), findsOneWidget);

    await tester.tap(find.text('ロン'));
    await tester.pump();

    expect(state.isOver, isTrue);
    expect(state.result!.reason, RoundOverReason.ron);
    expect(state.result!.winnerIndex, 0);
    expect(state.result!.dealtInIndex, 1);
    expect(find.textContaining('ロン和了'), findsOneWidget);
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

    expect(find.text('ポン'), findsOneWidget);
    expect(find.text('カン'), findsNothing); // only 2 matching tiles, not 3.
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

  testWidgets('a discard the viewer can daiminkan offers カン alongside ポン', (tester) async {
    final hands = [
      Hand(concealedTiles: [sou(9), sou(9), sou(9), ...filler(pin, 3, 10)]), // 3 matching: pon or kan.
      Hand(concealedTiles: filler(sou, 3, 13)),
      Hand(concealedTiles: filler(man, 1, 13)),
    ];
    final wall = Wall([sou(9), man(9), ...filler(pin, 1, 10)]);
    final state = GameState(hands: hands, wall: wall, dealerIndex: 1);
    state.drawForCurrentPlayer();
    state.discard(sou(9));

    await tester.pumpWidget(MaterialApp(home: GameScreen(state: state)));

    expect(find.text('ポン'), findsOneWidget);
    expect(find.text('カン'), findsOneWidget);
    expect(find.text('キャンセル'), findsOneWidget);

    await tester.tap(find.text('カン'));
    await tester.pump();

    expect(state.currentPlayerIndex, 0);
    expect(state.hands[0].melds, hasLength(1));
    expect(state.hands[0].melds.single.kind, MeldKind.kantsu);
    // 13 - 3 claimed into the kan + 1 kan replacement draw = 11.
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

  testWidgets('drawing a kita and choosing キャンセル keeps it in the hand', (tester) async {
    final hands = [
      Hand(concealedTiles: filler(pin, 3, 13)),
      Hand(concealedTiles: filler(sou, 3, 13)),
      Hand(concealedTiles: filler(man, 1, 13)),
    ];
    final wall = Wall([const KitaTile(), pin(2), pin(2)]);
    final state = GameState(hands: hands, wall: wall, dealerIndex: 0);

    await tester.pumpWidget(MaterialApp(home: GameScreen(state: state)));
    await tester.tap(find.text('キャンセル'));
    await tester.pump();

    expect(state.phase, TurnPhase.awaitingDiscard);
    expect(state.nukiTiles[0], isEmpty);
    expect(state.currentHand.concealedTiles, contains(const KitaTile()));
    expect(find.text('北'), findsOneWidget);
  });
}
