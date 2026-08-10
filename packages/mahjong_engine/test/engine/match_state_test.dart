import 'package:mahjong_engine/mahjong_engine.dart';
import 'package:test/test.dart';

NumberTile pin(int n) => NumberTile(NumberSuit.pin, n);
NumberTile sou(int n) => NumberTile(NumberSuit.sou, n);
NumberTile man(int n) => NumberTile(NumberSuit.man, n);

List<Tile> filler(NumberTile Function(int) suit, int rank, int count) =>
    List.generate(count, (_) => suit(rank));

Hand chiitoitsuTenpai() => Hand(concealedTiles: [
      for (var n = 1; n <= 6; n++) ...[pin(n), pin(n)],
      pin(7),
    ]);

void main() {
  final ruleset = SixKaSixPeiSanmaRuleset();

  group('MatchState', () {
    test('defaults every seat\'s score to the ruleset\'s own startingPoints toggle', () {
      final match = MatchState(ruleset: ruleset);
      expect(match.scores, [35000, 35000, 35000]);
    });

    test('roundLabel formats the wind, round number, and honba', () {
      final match = MatchState(ruleset: ruleset);
      expect(match.roundLabel, '東1局');

      match.honba = 2;
      expect(match.roundLabel, '東1局 2本場');
    });

    test('a non-dealer tsumo pays the dealer double and the other player single, and rotates the deal', () {
      final hands = [
        Hand(concealedTiles: filler(sou, 3, 13)), // dealer (player0).
        chiitoitsuTenpai(), // player1, wins.
        Hand(concealedTiles: filler(man, 1, 13)),
      ];
      final wall = Wall([sou(9), pin(7), pin(2), pin(2)]);
      final state = GameState(hands: hands, wall: wall, dealerIndex: 0);
      state.drawForCurrentPlayer();
      state.discard(sou(9));
      state.drawForCurrentPlayer(); // player1 draws pin(7), completing chiitoitsu.
      state.declareTsumo();

      final match = MatchState(ruleset: ruleset, startingScores: [35000, 35000, 35000]);
      match.advance(state);

      // 七対子 (2翻, fixed table): non-dealer tsumo = dealer pays 1000,
      // other opponent pays 1000.
      expect(match.scores, [35000 - 1000, 35000 + 2000, 35000 - 1000]);
      expect(match.dealerIndex, 1); // deal moves to the winner's seat.
      expect(match.honba, 0); // reset — a non-dealer won.
      expect(match.roundLabel, '東2局');
    });

    test('a dealer tsumo has both opponents pay double share each, and the dealer repeats', () {
      final hands = [
        chiitoitsuTenpai(), // dealer (player0), wins.
        Hand(concealedTiles: filler(sou, 3, 13)),
        Hand(concealedTiles: filler(man, 1, 13)),
      ];
      final wall = Wall([pin(7), pin(2), pin(2)]);
      final state = GameState(hands: hands, wall: wall, dealerIndex: 0);
      state.drawForCurrentPlayer();
      state.declareTsumo();

      final match = MatchState(ruleset: ruleset, startingScores: [35000, 35000, 35000]);
      match.advance(state);

      // Dealer tsumo, 2翻: 2000 all.
      expect(match.scores, [35000 + 4000, 35000 - 2000, 35000 - 2000]);
      expect(match.dealerIndex, 0); // 連荘 — same dealer again.
      expect(match.honba, 1);
      expect(match.roundLabel, '東1局 1本場');
    });

    test('a ron win only charges the discarder, and the deal rotates for a non-dealer winner', () {
      final hands = [
        Hand(concealedTiles: filler(sou, 3, 13)), // dealer — forced to discard pin(7) below.
        chiitoitsuTenpai(), // player1, wins by ron.
        Hand(concealedTiles: filler(man, 1, 13)),
      ];
      final wall = Wall([pin(7), pin(8), pin(9)]);
      final state = GameState(hands: hands, wall: wall, dealerIndex: 0);
      state.drawForCurrentPlayer();
      state.discard(pin(7));
      expect(state.canDeclareRon(1), isTrue);
      state.declareRon(1);

      final match = MatchState(ruleset: ruleset, startingScores: [35000, 35000, 35000]);
      match.advance(state);

      // 七対子 (2翻): non-dealer ron = 2000, charged only to the discarder.
      expect(match.scores, [35000 - 2000, 35000 + 2000, 35000]);
      expect(match.dealerIndex, 1);
      expect(match.honba, 0);
    });

    test('an exhaustive draw keeps the same dealer only if they\'re tenpai, and always grows honba', () {
      final tenpaiDealer = chiitoitsuTenpai(); // tenpai (0-shanten), waiting on pin(7).
      final hands = [
        tenpaiDealer,
        Hand(concealedTiles: filler(sou, 3, 13)),
        Hand(concealedTiles: filler(man, 1, 13)),
      ];
      // 5 tiles - 2 reserved dora indicators = 3 live draws before exhaustion.
      final wall = Wall([pin(9), pin(2), pin(4), pin(5), pin(6)]);
      final state = GameState(hands: hands, wall: wall, dealerIndex: 0);
      for (var i = 0; i < 3; i++) {
        state.drawForCurrentPlayer();
        state.discard(state.currentHand.concealedTiles.last);
      }
      state.drawForCurrentPlayer();
      expect(state.result!.reason, RoundOverReason.exhaustiveDraw);

      final match = MatchState(ruleset: ruleset, startingScores: [35000, 35000, 35000]);
      match.advance(state);

      expect(match.scores, [35000, 35000, 35000]); // no tenpai/noten payment yet.
      expect(match.dealerIndex, 0); // dealer's hand was still tenpai — 連荘.
      expect(match.honba, 1);
    });

    test('the match ends once 南3局 finishes without the dealer repeating', () {
      final match = MatchState(ruleset: ruleset, wind: RoundWind.south, roundNumber: 3, dealerIndex: 2);

      final hands = [
        chiitoitsuTenpai(), // player0, wins by ron.
        Hand(concealedTiles: filler(sou, 3, 13)),
        Hand(concealedTiles: filler(man, 1, 13)), // dealer (player2) — forced to discard pin(7) below.
      ];
      final wall = Wall([pin(7), pin(8), pin(9)]);
      final state = GameState(hands: hands, wall: wall, dealerIndex: 2);
      state.drawForCurrentPlayer();
      state.discard(pin(7));
      expect(state.canDeclareRon(0), isTrue);
      state.declareRon(0);

      match.advance(state);

      expect(match.isOver, isTrue);
    });
  });
}
