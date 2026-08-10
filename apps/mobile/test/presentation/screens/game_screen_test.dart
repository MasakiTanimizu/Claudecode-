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
    // Dealer tsumo, 七対子 (2翻/25符 — the fixed low-han table ignores fu):
    // 2000 all.
    expect(find.textContaining('2000点オール'), findsOneWidget);
  });

  testWidgets('a non-dealer\'s tsumo win shows separate payments for the dealer and the other opponent', (tester) async {
    final tenpaiHand = Hand(concealedTiles: [
      for (var n = 1; n <= 6; n++) ...[pin(n), pin(n)],
      pin(7),
    ]);
    final hands = [
      Hand(concealedTiles: filler(sou, 3, 13)), // dealer (player0).
      tenpaiHand, // player1, the winner.
      Hand(concealedTiles: filler(man, 1, 13)),
    ];
    final wall = Wall([sou(9), pin(7), pin(2), pin(2)]);
    final state = GameState(hands: hands, wall: wall, dealerIndex: 0);
    state.drawForCurrentPlayer(); // player0 (dealer) draws and discards junk first.
    state.discard(sou(9));

    // The viewer is player1 here: they draw pin(7) automatically once it's
    // their turn, completing the chiitoitsu hand.
    await tester.pumpWidget(MaterialApp(home: GameScreen(state: state, viewerIndex: 1)));

    expect(find.text('和了'), findsOneWidget);
    await tester.tap(find.text('和了'));
    await tester.pump();

    expect(state.isOver, isTrue);
    // Non-dealer tsumo, 七対子 (2翻/25符 — fixed low-han table): both
    // opponents pay 1000 regardless of whether they're the dealer.
    expect(find.textContaining('プレイヤー0から1000点・プレイヤー2から1000点'), findsOneWidget);
  });

  testWidgets('a ron win shows the discarder\'s payment', (tester) async {
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
    await tester.tap(find.text('ロン'));
    await tester.pump();

    expect(state.isOver, isTrue);
    // Non-dealer ron, 七対子 (2翻/25符): 2000 points from the discarder.
    expect(find.textContaining('2000点'), findsOneWidget);
  });

  testWidgets('リーチ then double-tapping a tenpai-preserving tile declares riichi', (tester) async {
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

    await tester.pumpWidget(MaterialApp(home: GameScreen(state: state)));

    expect(find.text('リーチ'), findsOneWidget);
    await tester.tap(find.text('リーチ'));
    await tester.pump();
    expect(find.text('リーチ選択中（キャンセル）'), findsOneWidget);

    await tester.tap(find.text('9m'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('9m'));
    await tester.pump();

    expect(state.riichiDeclared, contains(0));
    expect(state.discardPiles[0], [man(9)]);
    // Flush the gesture recognizer's own internal timer so the test
    // framework doesn't see it as still pending at teardown.
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('リーチ選択中 ignores a tap on a tile that wouldn\'t keep the hand tenpai', (tester) async {
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

    await tester.pumpWidget(MaterialApp(home: GameScreen(state: state)));
    await tester.tap(find.text('リーチ'));
    await tester.pump();

    await tester.tap(find.text('1p'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('1p'));
    await tester.pump();

    expect(state.riichiDeclared, isEmpty);
    expect(state.discardPiles[0], isEmpty);
    expect(find.text('リーチ選択中（キャンセル）'), findsOneWidget); // still picking.
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('暗槓 appears with 4 matching concealed tiles and declares an ankan', (tester) async {
    final hands = [
      Hand(concealedTiles: [pin(1), pin(1), pin(1), pin(1), ...filler(sou, 3, 9)]),
      Hand(concealedTiles: filler(sou, 3, 13)),
      Hand(concealedTiles: filler(man, 1, 13)),
    ];
    final wall = Wall([man(9), pin(2), pin(2)]);
    final state = GameState(hands: hands, wall: wall, dealerIndex: 0);

    await tester.pumpWidget(MaterialApp(home: GameScreen(state: state)));

    expect(find.text('暗槓'), findsOneWidget);
    await tester.tap(find.text('暗槓'));
    await tester.pump();

    expect(state.hands[0].melds, hasLength(1));
    expect(state.hands[0].melds.single.kind, MeldKind.kantsu);
    expect(state.hands[0].melds.single.source, CallSource.ankan);
  });

  testWidgets('加槓 appears with a concealed tile matching an existing pon and upgrades it', (tester) async {
    final hands = [
      Hand(
        concealedTiles: [pin(1), ...filler(sou, 3, 9)],
        melds: [
          Meld.kotsu(
            [DragonTile(Dragon.white), DragonTile(Dragon.white), DragonTile(Dragon.white)],
            source: CallSource.pon,
          ),
        ],
      ),
      Hand(concealedTiles: filler(sou, 3, 13)),
      Hand(concealedTiles: filler(man, 1, 13)),
    ];
    final wall = Wall([DragonTile(Dragon.white), pin(2), pin(2)]);
    final state = GameState(hands: hands, wall: wall, dealerIndex: 0);

    await tester.pumpWidget(MaterialApp(home: GameScreen(state: state)));

    expect(find.text('加槓'), findsOneWidget);
    await tester.tap(find.text('加槓'));
    await tester.pump();

    expect(state.hands[0].melds, hasLength(1));
    expect(state.hands[0].melds.single.kind, MeldKind.kantsu);
    expect(state.hands[0].melds.single.source, CallSource.shouminkan);
  });

  testWidgets('a CPU declares riichi when its chosen discard would keep it tenpai', (tester) async {
    final cpuRiichiReadyHand = Hand(concealedTiles: [
      pin(1), pin(2), pin(3),
      pin(4), pin(5), pin(6),
      pin(7), pin(8), pin(9),
      DragonTile(Dragon.white), DragonTile(Dragon.white),
      sou(4), sou(5),
    ]);
    final hands = [
      Hand(concealedTiles: filler(man, 1, 13)),
      cpuRiichiReadyHand,
      Hand(concealedTiles: filler(sou, 3, 13)),
    ];
    final wall = Wall([man(1), man(9), sou(9), pin(1), pin(1)]);
    final state = GameState(hands: hands, wall: wall, dealerIndex: 0);

    await tester.pumpWidget(MaterialApp(home: GameScreen(state: state)));

    await tester.tap(find.text('1m').first);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('1m').first);
    await tester.pump();

    expect(state.riichiDeclared, contains(1));
    expect(state.discardPiles[1], contains(man(9)));
    // Flush the gesture recognizer's own internal timer so the test
    // framework doesn't see it as still pending at teardown.
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('an already-riichi CPU is forced to discard exactly the tile it just drew, even when chooseDiscard would otherwise prefer a different one', (tester) async {
    // Regression: _runCpuTurns used to call chooseDiscard(_state.currentHand)
    // unconditionally, ignoring GameState.discard's own invariant that a
    // riichi'd hand may only ever discard the tile it just drew. That's
    // usually unobservable — a "clean" tenpai hand's only shanten-preserving
    // discard already is the drawn tile — but ties happen, most commonly a
    // chiitoitsu tenpai (6 pairs + 1 spare): drawing any unrelated tile
    // leaves two equally-good chiitoitsu discards (the spare, or the new
    // tile), and chooseDiscard's tie-break lands on the spare here
    // (confirmed directly against chooseDiscard before writing this test),
    // throwing "a riichi hand can only discard the tile just drawn".
    final chiitoitsuTenpaiHand = Hand(concealedTiles: [
      man(1), man(1), man(9), man(9),
      pin(1), pin(1), pin(9), pin(9),
      sou(1), sou(1), sou(9), sou(9),
      DragonTile(Dragon.white),
    ]);
    final hands = [
      Hand(concealedTiles: filler(pin, 3, 13)),
      chiitoitsuTenpaiHand,
      Hand(concealedTiles: filler(man, 1, 13)),
    ];
    final wall = Wall([sou(5), pin(2), pin(2)]);
    final state = GameState(hands: hands, wall: wall, dealerIndex: 1);
    state.riichiDeclared.add(1); // simulate a riichi already in effect.

    await tester.pumpWidget(MaterialApp(home: GameScreen(state: state)));

    expect(tester.takeException(), isNull);
    expect(state.discardPiles[1], contains(sou(5)));
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
    // Also shown as a popup, not just recorded on the engine side — see
    // GameScreen's class doc for why it's popup+badge instead of a
    // SnackBar/timer-based notification.
    expect(find.textContaining('プレイヤー0が夏を抜きました'), findsOneWidget);
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

  testWidgets('mounting with a non-viewer dealer drives their (and the third player\'s) turn automatically', (tester) async {
    // Regression: initState only ever called _resolveKitaDecisionsForCpu
    // (handles a pending 抜く/キャンセル decision) and
    // _autoDrawForViewerIfNeeded (only fires on the viewer's own turn) —
    // neither one draws+discards for a CPU's perfectly ordinary turn. With
    // dealerIndex != viewerIndex and no kita anywhere in sight (so
    // _resolveKitaDecisionsForCpu is a no-op from the very first frame),
    // the game used to freeze immediately on mount, nothing yet pressed.
    // Fuzzed against 30,000 random deals across all 3 possible dealers to
    // confirm the fix (adding a _runCpuTurns call) actually closes this —
    // this test is the minimal, deterministic version of that same gap.
    final hands = [
      Hand(concealedTiles: filler(pin, 3, 13)), // viewer (player0).
      Hand(concealedTiles: filler(sou, 3, 13)), // dealer (player1) — a CPU.
      Hand(concealedTiles: filler(man, 1, 13)),
    ];
    final wall = Wall([sou(9), man(9), pin(9), pin(2), pin(2)]);
    final state = GameState(hands: hands, wall: wall, dealerIndex: 1);

    await tester.pumpWidget(MaterialApp(home: GameScreen(state: state)));

    expect(state.discardPiles[1], hasLength(1)); // the dealer (CPU) drew and discarded.
    expect(state.discardPiles[2], hasLength(1)); // then the third player did too.
    expect(state.currentPlayerIndex, 0); // now the viewer's turn.
    expect(state.phase, TurnPhase.awaitingDiscard);
    expect(state.hands[0].concealedTiles, hasLength(14)); // auto-drew for the viewer too.
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

  testWidgets('抜く when the replacement draw is also a kita re-offers 抜く/キャンセル for the new one', (tester) async {
    final hands = [
      Hand(concealedTiles: filler(pin, 3, 13)),
      Hand(concealedTiles: filler(sou, 3, 13)),
      Hand(concealedTiles: filler(man, 1, 13)),
    ];
    // 5 tiles: the front 3 (K, K, 2p) get drawn; the back 2 (3p, 4p) are
    // the wall's default 2-tile dora-indicator reserve and are never drawn
    // (Wall.remainingLiveCount excludes them) — need enough live tiles for
    // all 3 draws this test exercises, not just the 2 the tile count alone
    // would suggest.
    final wall = Wall([const KitaTile(), const KitaTile(), pin(2), pin(3), pin(4)]);
    final state = GameState(hands: hands, wall: wall, dealerIndex: 0);

    await tester.pumpWidget(MaterialApp(home: GameScreen(state: state)));

    expect(find.text('抜く'), findsOneWidget);
    expect(state.phase, TurnPhase.awaitingKitaDecision);

    await tester.tap(find.text('抜く'));
    await tester.pump();

    // The replacement draw was itself a kita — still the viewer's own
    // pending decision, so 抜く/キャンセル must be offered again for it
    // rather than the screen going quiet with nothing to press.
    expect(state.phase, TurnPhase.awaitingKitaDecision);
    expect(find.text('抜く'), findsOneWidget);
    expect(state.nukiTiles[0], [const KitaTile()]);

    await tester.tap(find.text('抜く'));
    await tester.pump();

    expect(state.phase, TurnPhase.awaitingDiscard);
    expect(state.nukiTiles[0], [const KitaTile(), const KitaTile()]);
    expect(find.text('2p'), findsOneWidget);
  });

  testWidgets('the drawn-but-undecided kita is shown in the hand while the choice is pending', (tester) async {
    final hands = [
      Hand(concealedTiles: filler(pin, 3, 13)),
      Hand(concealedTiles: filler(sou, 3, 13)),
      Hand(concealedTiles: filler(man, 1, 13)),
    ];
    final wall = Wall([const KitaTile(), pin(9), pin(2), pin(2)]);
    final state = GameState(hands: hands, wall: wall, dealerIndex: 0);

    await tester.pumpWidget(MaterialApp(home: GameScreen(state: state)));

    expect(state.phase, TurnPhase.awaitingKitaDecision);
    // Not actually in the engine's hand yet — only keepDrawnKita() puts it
    // there — but shown in the UI so the viewer can see what they're being
    // asked to keep or nuku, instead of just an unexplained 抜く/キャンセル.
    expect(state.currentHand.concealedTiles, isNot(contains(const KitaTile())));
    expect(find.text('北'), findsOneWidget);
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

  testWidgets('a CPU auto-declares ron on the viewer\'s discard', (tester) async {
    final chiitoitsuTenpai = Hand(concealedTiles: [
      for (var n = 1; n <= 6; n++) ...[pin(n), pin(n)],
      pin(7),
    ]);
    final hands = [
      Hand(concealedTiles: filler(sou, 3, 13)), // viewer/dealer: draws and discards 7p.
      chiitoitsuTenpai, // CPU, waiting on 7p.
      Hand(concealedTiles: filler(man, 1, 13)),
    ];
    final wall = Wall([pin(7), pin(8), pin(9)]); // 1 live draw (7p) + 2 reserved.
    final state = GameState(hands: hands, wall: wall, dealerIndex: 0);

    await tester.pumpWidget(MaterialApp(home: GameScreen(state: state)));

    await tester.tap(find.text('7p'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('7p'));
    await tester.pump();

    expect(state.isOver, isTrue);
    expect(state.result!.reason, RoundOverReason.ron);
    expect(state.result!.winnerIndex, 1);
    expect(state.result!.dealtInIndex, 0);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a CPU auto-calls ポン on the viewer\'s discard when it helps their hand', (tester) async {
    final hands = [
      Hand(concealedTiles: filler(sou, 3, 13)), // viewer/dealer: draws and discards 白.
      Hand(concealedTiles: [
        DragonTile(Dragon.white), DragonTile(Dragon.white),
        pin(1), pin(3), pin(5), pin(7), pin(9),
        sou(2), sou(4), sou(6), sou(8),
        man(1), man(9),
      ]), // CPU: an isolated pair the pon turns into a real group.
      Hand(concealedTiles: filler(man, 1, 13)),
    ];
    final wall = Wall([DragonTile(Dragon.white), pin(2), pin(3), pin(4), pin(5)]);
    final state = GameState(hands: hands, wall: wall, dealerIndex: 0);

    await tester.pumpWidget(MaterialApp(home: GameScreen(state: state)));

    await tester.tap(find.text('白'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('白'));
    await tester.pump();

    expect(state.hands[1].melds, hasLength(1));
    expect(state.hands[1].melds.single.kind, MeldKind.kotsu);
    expect(state.hands[1].melds.single.source, CallSource.pon);
    // The call forces an immediate discard of their own.
    expect(state.discardPiles[1], hasLength(1));
    await tester.pump(const Duration(seconds: 1));
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

  testWidgets('次局へ applies the match result and deals a fresh round', (tester) async {
    final tenpaiHand = Hand(concealedTiles: [
      for (var n = 1; n <= 6; n++) ...[pin(n), pin(n)],
      pin(7),
    ]);
    final hands = [
      tenpaiHand, // dealer (player0), wins.
      Hand(concealedTiles: filler(sou, 3, 13)),
      Hand(concealedTiles: filler(man, 1, 13)),
    ];
    final wall = Wall([pin(7), pin(2), pin(2)]);
    final state = GameState(hands: hands, wall: wall, dealerIndex: 0);
    final ruleset = SixKaSixPeiSanmaRuleset();
    final match = MatchState(ruleset: ruleset, startingScores: [35000, 35000, 35000]);

    await tester.pumpWidget(MaterialApp(home: GameScreen(state: state, match: match)));

    expect(find.text('和了'), findsOneWidget);
    await tester.tap(find.text('和了'));
    await tester.pump();

    expect(find.text('次局へ'), findsOneWidget);
    await tester.tap(find.text('次局へ'));
    await tester.pump();

    // Dealer tsumo, 七対子 (2翻): 2000 all — the dealer repeats (連荘).
    expect(match.scores, [35000 + 4000, 35000 - 2000, 35000 - 2000]);
    expect(match.dealerIndex, 0);
    expect(match.honba, 1);
    expect(find.text('自分の手牌'), findsOneWidget); // back on the board for the fresh round.
    expect(find.text('次局へ'), findsNothing); // the new round isn't over.
  });

  testWidgets('次局へ shows the final-results screen once the match ends', (tester) async {
    final tenpaiHand = Hand(concealedTiles: [
      for (var n = 1; n <= 6; n++) ...[pin(n), pin(n)],
      pin(7),
    ]);
    final hands = [
      Hand(concealedTiles: filler(sou, 3, 13)), // dealer (player0).
      tenpaiHand, // player1, wins — a non-dealer win ends 南3局's match.
      Hand(concealedTiles: filler(man, 1, 13)),
    ];
    final wall = Wall([sou(9), pin(7), pin(2), pin(2)]);
    final state = GameState(hands: hands, wall: wall, dealerIndex: 0);
    state.drawForCurrentPlayer();
    state.discard(sou(9));

    final ruleset = SixKaSixPeiSanmaRuleset();
    final match = MatchState(ruleset: ruleset, wind: RoundWind.south, roundNumber: 3, dealerIndex: 0);

    await tester.pumpWidget(MaterialApp(home: GameScreen(state: state, match: match, viewerIndex: 1)));

    expect(find.text('和了'), findsOneWidget);
    await tester.tap(find.text('和了'));
    await tester.pump();
    await tester.tap(find.text('次局へ'));
    await tester.pump();

    expect(match.isOver, isTrue);
    expect(find.text('半荘終了'), findsOneWidget);
    expect(find.text('最終結果'), findsOneWidget);
  });
}
