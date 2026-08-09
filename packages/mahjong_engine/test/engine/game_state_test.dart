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

  group('GameState kan', () {
    test('ankan: 4 concealed copies, reveals dora and draws a replacement', () {
      final hands = [
        Hand(concealedTiles: [...filler(pin, 1, 4), ...filler(sou, 3, 9)]),
        Hand(concealedTiles: filler(sou, 5, 13)),
        Hand(concealedTiles: filler(man, 1, 13)),
      ];
      final wall = Wall([pin(9), pin(7), pin(2), pin(2), pin(2), pin(2)]);
      final state = GameState(hands: hands, wall: wall, dealerIndex: 0);

      state.drawForCurrentPlayer(); // p0 draws pin(9), unrelated to the kan.
      expect(state.canDeclareAnkan(pin(1)), isTrue);

      state.declareAnkan(pin(1));
      expect(state.wall.doraIndicators, hasLength(3));
      expect(state.hands[0].melds, hasLength(1));
      expect(state.hands[0].melds.single.kind, MeldKind.kantsu);
      expect(state.hands[0].melds.single.source, CallSource.ankan);
      expect(state.hands[0].melds.single.isOpen, isFalse);
      expect(state.hands[0].concealedTiles, hasLength(11)); // 9 sou3 + pin9 + pin7 replacement.
      expect(state.phase, TurnPhase.awaitingDiscard);
      expect(state.currentPlayerIndex, 0);
    });

    test('daiminkan: another player claims the discard with 3 matching tiles', () {
      final hands = [
        Hand(concealedTiles: filler(pin, 3, 13)),
        Hand(concealedTiles: [...filler(pin, 9, 3), ...filler(sou, 3, 10)]),
        Hand(concealedTiles: filler(man, 1, 13)),
      ];
      final wall = Wall([pin(9), pin(7), sou(1), sou(1), pin(2), pin(2)]);
      final state = GameState(hands: hands, wall: wall, dealerIndex: 0);

      state.drawForCurrentPlayer(); // p0 draws pin(9)
      state.discard(pin(9));

      expect(state.canDeclareDaiminkan(1), isTrue);
      state.declareDaiminkan(1);

      expect(state.wall.doraIndicators, hasLength(3));
      expect(state.hands[1].melds, hasLength(1));
      expect(state.hands[1].melds.single.kind, MeldKind.kantsu);
      expect(state.hands[1].melds.single.source, CallSource.daiminkan);
      expect(state.hands[1].melds.single.isOpen, isTrue);
      expect(state.hands[1].concealedTiles, hasLength(11)); // 10 sou3 + pin7 replacement.
      expect(state.phase, TurnPhase.awaitingDiscard);
      expect(state.currentPlayerIndex, 1);
    });

    test('shouminkan: upgrading an existing pon with the 4th matching tile', () {
      final hands = [
        Hand(
          concealedTiles: filler(sou, 3, 10),
          melds: [
            Meld.kotsu([pin(7), pin(7), pin(7)], source: CallSource.pon),
          ],
        ),
        Hand(concealedTiles: filler(sou, 5, 13)),
        Hand(concealedTiles: filler(man, 1, 13)),
      ];
      final wall = Wall([pin(7), pin(9), pin(2), pin(2), pin(2)]);
      final state = GameState(hands: hands, wall: wall, dealerIndex: 0);

      state.drawForCurrentPlayer(); // p0 draws the 4th pin(7).
      expect(state.canDeclareShouminkan(pin(7)), isTrue);

      state.declareShouminkan(pin(7));
      expect(state.wall.doraIndicators, hasLength(3));
      expect(state.hands[0].melds, hasLength(1)); // replaced, not appended.
      expect(state.hands[0].melds.single.kind, MeldKind.kantsu);
      expect(state.hands[0].melds.single.source, CallSource.shouminkan);
      expect(state.hands[0].melds.single.isOpen, isTrue);
      expect(state.hands[0].concealedTiles, hasLength(11)); // 10 sou3 + pin9 replacement.
      expect(state.phase, TurnPhase.awaitingDiscard);
    });

    test('a riichi hand can never ankan, daiminkan into, or shouminkan', () {
      final hands = [
        Hand(
          concealedTiles: [...filler(pin, 1, 4), ...filler(sou, 3, 9)],
          melds: [
            Meld.kotsu([pin(7), pin(7), pin(7)], source: CallSource.pon),
          ],
        ),
        Hand(concealedTiles: [...filler(pin, 9, 3), ...filler(sou, 3, 10)]),
        Hand(concealedTiles: filler(man, 1, 13)),
      ];
      final wall = Wall([pin(9), pin(7), pin(2), pin(2)]);
      final state = GameState(hands: hands, wall: wall, dealerIndex: 0);
      state.riichiDeclared.add(0);
      state.riichiDeclared.add(1);

      state.drawForCurrentPlayer(); // p0 draws pin(9)
      expect(state.canDeclareAnkan(pin(1)), isFalse);
      expect(state.canDeclareShouminkan(pin(7)), isFalse);

      state.discard(pin(9));
      expect(state.canDeclareDaiminkan(1), isFalse);
    });

    test('exhaustive draw if the wall cannot cover the kan reveal + replacement draw', () {
      final hands = [
        Hand(concealedTiles: [...filler(pin, 1, 4), ...filler(sou, 3, 9)]),
        Hand(concealedTiles: filler(sou, 5, 13)),
        Hand(concealedTiles: filler(man, 1, 13)),
      ];
      // 4 tiles: 2 reserved dora indicators, 2 live. One is used by the
      // initial draw, leaving only 1 live — not enough for the kan's own
      // reveal (1) + replacement draw (1).
      final wall = Wall([pin(9), pin(2), pin(2), pin(2)]);
      final state = GameState(hands: hands, wall: wall, dealerIndex: 0);

      state.drawForCurrentPlayer();
      state.declareAnkan(pin(1));

      expect(state.isOver, isTrue);
      expect(state.result!.reason, RoundOverReason.exhaustiveDraw);
    });
  });

  group('GameState kita/hana nuki', () {
    test('a drawn hana tile is auto-nuku\'d and replaced, never entering the hand', () {
      final hands = [
        Hand(concealedTiles: filler(pin, 3, 13)),
        Hand(concealedTiles: filler(sou, 3, 13)),
        Hand(concealedTiles: filler(man, 1, 13)),
      ];
      final wall = Wall([const HanaTile(HanaKind.spring), pin(9), pin(2), pin(2)]);
      final state = GameState(hands: hands, wall: wall, dealerIndex: 0);

      state.drawForCurrentPlayer();

      expect(state.phase, TurnPhase.awaitingDiscard);
      expect(state.currentHand.concealedTiles, hasLength(14));
      expect(state.currentHand.concealedTiles, isNot(contains(const HanaTile(HanaKind.spring))));
      expect(state.currentHand.concealedTiles.last, pin(9));
      expect(state.nukiTiles[0], [const HanaTile(HanaKind.spring)]);
    });

    test('a drawn kita tile pauses at awaitingKitaDecision instead of entering the hand', () {
      final hands = [
        Hand(concealedTiles: filler(pin, 3, 13)),
        Hand(concealedTiles: filler(sou, 3, 13)),
        Hand(concealedTiles: filler(man, 1, 13)),
      ];
      final wall = Wall([const KitaTile(), pin(2), pin(2)]);
      final state = GameState(hands: hands, wall: wall, dealerIndex: 0);

      state.drawForCurrentPlayer();

      expect(state.phase, TurnPhase.awaitingKitaDecision);
      expect(state.hasPendingKitaDecision, isTrue);
      expect(state.pendingKitaTile, const KitaTile());
      expect(state.currentHand.concealedTiles, hasLength(13));
    });

    test('nukiKita reveals the kita publicly and draws a replacement', () {
      final hands = [
        Hand(concealedTiles: filler(pin, 3, 13)),
        Hand(concealedTiles: filler(sou, 3, 13)),
        Hand(concealedTiles: filler(man, 1, 13)),
      ];
      final wall = Wall([const KitaTile(), pin(9), pin(2), pin(2)]);
      final state = GameState(hands: hands, wall: wall, dealerIndex: 0);
      state.drawForCurrentPlayer();

      state.nukiKita();

      expect(state.phase, TurnPhase.awaitingDiscard);
      expect(state.nukiTiles[0], [const KitaTile()]);
      expect(state.currentHand.concealedTiles, hasLength(14));
      expect(state.currentHand.concealedTiles.last, pin(9));
    });

    test('keepDrawnKita keeps the tile in hand instead of nuku\'ing it', () {
      final hands = [
        Hand(concealedTiles: filler(pin, 3, 13)),
        Hand(concealedTiles: filler(sou, 3, 13)),
        Hand(concealedTiles: filler(man, 1, 13)),
      ];
      final wall = Wall([const KitaTile(), pin(2), pin(2)]);
      final state = GameState(hands: hands, wall: wall, dealerIndex: 0);
      state.drawForCurrentPlayer();

      state.keepDrawnKita();

      expect(state.phase, TurnPhase.awaitingDiscard);
      expect(state.nukiTiles[0], isEmpty);
      expect(state.currentHand.concealedTiles, hasLength(14));
      expect(state.currentHand.concealedTiles, contains(const KitaTile()));
    });

    test('a kita kept in hand can never be discarded', () {
      final hands = [
        Hand(concealedTiles: filler(pin, 3, 13)),
        Hand(concealedTiles: filler(sou, 3, 13)),
        Hand(concealedTiles: filler(man, 1, 13)),
      ];
      final wall = Wall([const KitaTile(), pin(2), pin(2)]);
      final state = GameState(hands: hands, wall: wall, dealerIndex: 0);
      state.drawForCurrentPlayer();
      state.keepDrawnKita();

      expect(() => state.discard(const KitaTile()), throwsStateError);
    });

    test('discard rejects a hana even if one is somehow sitting in the hand', () {
      // Every real hand-entry point auto-nuku's hana on sight, so this
      // constructs the "shouldn't happen" case directly, as a last-resort
      // guard check rather than a reachable-in-practice scenario.
      final hands = [
        Hand(concealedTiles: [const HanaTile(HanaKind.spring), ...filler(pin, 3, 12)]),
        Hand(concealedTiles: filler(sou, 3, 13)),
        Hand(concealedTiles: filler(man, 1, 13)),
      ];
      final wall = Wall([pin(2), pin(2), pin(2)]);
      final state = GameState(hands: hands, wall: wall, dealerIndex: 0);
      state.drawForCurrentPlayer();

      expect(() => state.discard(const HanaTile(HanaKind.spring)), throwsStateError);
    });

    test('a riichi\'d player\'s kita is always auto-nuku\'d, never pausing for a decision', () {
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
      final wall = Wall([man(9), pin(9), sou(9), const KitaTile(), man(1), pin(2), pin(2)]);
      final state = GameState(hands: hands, wall: wall, dealerIndex: 0);

      state.drawForCurrentPlayer();
      state.declareRiichiAndDiscard(man(9));
      state.drawForCurrentPlayer();
      state.discard(state.currentHand.concealedTiles.last); // p1 tsumogiri
      state.drawForCurrentPlayer();
      state.discard(state.currentHand.concealedTiles.last); // p2 tsumogiri

      state.drawForCurrentPlayer(); // p0 draws the kita (auto-nuku'd), then man(1).

      expect(state.phase, TurnPhase.awaitingDiscard);
      expect(state.hasPendingKitaDecision, isFalse);
      expect(state.nukiTiles[0], [const KitaTile()]);
      expect(state.currentHand.concealedTiles, hasLength(14));
      expect(state.currentHand.concealedTiles, isNot(contains(const KitaTile())));
      state.discard(man(1)); // only the just-drawn tile is legal for a riichi hand.
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
      // This particular seed/deal may or may not hand someone a haipai
      // kita — resolve it deterministically either way before asserting
      // the "ready to play" invariants below.
      while (state.hasPendingKitaDecision) {
        state.nukiKita();
      }

      expect(state.hands, hasLength(3));
      for (final hand in state.hands) {
        expect(hand.concealedTiles, hasLength(13));
      }
      expect(state.wall.tiles, hasLength(totalTileCount - 3 * 13));
      expect(state.currentPlayerIndex, 2);
      expect(state.phase, TurnPhase.awaitingDraw);
    });

    test('a hana dealt straight into a starting hand (haipai) is auto-nuku\'d, never left discardable', () {
      // A real 116-tile set has plenty of wall buffer (77 tiles after
      // dealing) relative to the 6 hana it contains, so resolving every
      // haipai hana can never run the wall dry. Sweep several seeds: the
      // core assertion (no hand ever holds a hana tile, immediately after
      // .deal() — hana resolves before any kita walk even starts) must
      // hold for every one of them, and across enough seeds at least one
      // is expected to actually deal a hana into some hand, exercising the
      // fix rather than passing vacuously.
      final fullSet = buildFullTileSet(markPreset: DoraMarkPreset.allRed);
      var totalNukiHana = 0;

      for (var seed = 0; seed < 30; seed++) {
        final state = GameState.deal(
          fullTileSet: fullSet,
          playerCount: 3,
          random: Random(seed),
          dealerIndex: 0,
        );

        for (final hand in state.hands) {
          expect(hand.concealedTiles.whereType<HanaTile>(), isEmpty);
        }
        totalNukiHana +=
            state.nukiTiles.expand((tiles) => tiles).whereType<HanaTile>().length;
      }

      expect(totalNukiHana, greaterThan(0));
    });

    test('a kita dealt straight into a starting hand (haipai) offers the same 抜く/keep choice a drawn one does', () {
      // 42 tiles total: 39 get dealt (13×3), so the wall always ends up
      // with exactly 3 — with 4 kita tiles and zero hana in the pool, at
      // least 1 kita must land in some hand no matter how the shuffle
      // falls (pigeonhole: the wall can only ever absorb 3 of the 4).
      // Always choosing to *keep* every offered kita needs no wall draws
      // at all, so this doesn't depend on the wall having any particular
      // amount of spare capacity.
      final fullSet = [
        const KitaTile(),
        const KitaTile(),
        const KitaTile(),
        const KitaTile(),
        ...filler(pin, 1, 38),
      ];
      final state = GameState.deal(
        fullTileSet: fullSet,
        playerCount: 3,
        random: Random(0),
        dealerIndex: 0,
      );

      expect(state.hasPendingKitaDecision, isTrue);
      while (state.hasPendingKitaDecision) {
        expect(state.pendingKitaTile, const KitaTile());
        state.keepDrawnKita();
      }

      expect(state.phase, TurnPhase.awaitingDraw);
      expect(state.currentPlayerIndex, 0);
      expect(state.nukiTiles.every((tiles) => tiles.isEmpty), isTrue);
      var totalKeptKita = 0;
      for (final hand in state.hands) {
        expect(hand.concealedTiles, hasLength(13));
        totalKeptKita += hand.concealedTiles.whereType<KitaTile>().length;
      }
      expect(totalKeptKita, greaterThanOrEqualTo(1));
    });

    test('choosing 抜く for a haipai kita reveals it and draws a replacement, same as mid-round', () {
      // Real 116-tile deck: plenty of wall buffer for whatever replacement
      // draws nuku'ing every offered kita ends up needing.
      final fullSet = buildFullTileSet(markPreset: DoraMarkPreset.allRed);
      var totalNukiKita = 0;

      for (var seed = 0; seed < 30; seed++) {
        final state = GameState.deal(
          fullTileSet: fullSet,
          playerCount: 3,
          random: Random(seed),
          dealerIndex: 0,
        );
        while (state.hasPendingKitaDecision) {
          state.nukiKita();
        }

        expect(state.phase, TurnPhase.awaitingDraw);
        for (final hand in state.hands) {
          expect(hand.concealedTiles, hasLength(13));
          expect(hand.concealedTiles.whereType<KitaTile>(), isEmpty);
        }
        totalNukiKita +=
            state.nukiTiles.expand((tiles) => tiles).whereType<KitaTile>().length;
      }

      expect(totalNukiKita, greaterThan(0));
    });
  });
}
