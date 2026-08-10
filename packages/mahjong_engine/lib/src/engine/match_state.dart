/// A 半荘's running state above a single 局 (round-to-round continuation:
/// scores, whose deal it is, honba/repeat count).
///
/// This is deliberately a thin layer over [RulesetDefinition]/[GameState],
/// not a reimplementation of either — it only tracks what carries over
/// BETWEEN rounds (scores, dealer seat, wind/round number, honba) and
/// applies one round's [RoundResult] to that running state. It never holds
/// a [GameState] itself; callers deal a fresh one for each 局 via
/// [dealCurrentRound] and, once that round ends, feed it back through
/// [advance].
///
/// Score transfer only covers 和了 (tsumo/ron), via the same
/// [RulesetDefinition.scoreWin] the single-round UI already uses for its
/// result banner. A 流局 (exhaustive draw) carries no tenpai/noten payment
/// here — a deliberate simplification (real rules pay a fixed pot split by
/// who's tenpai) left for later since it needs per-player tenpai
/// visibility this layer doesn't otherwise need. Dealer repeat (連荘) on a
/// draw is still modeled correctly via each player's own hand shanten.
library;

import 'dart:math';

import '../core/hand.dart';
import '../rulesets/ruleset_definition.dart';
import 'game_state.dart';
import 'overall_shanten.dart';
import 'scoring.dart';

/// The two winds this ruleset's 半荘 plays through, one after the other —
/// there's no 北 wind rotation to worry about on a 3-player table.
enum RoundWind { east, south }

/// One 局's worth of round-continuation bookkeeping, produced by
/// [MatchState.advance] and consumed by the next [MatchState.dealCurrentRound]
/// call — see [MatchState]'s own doc for the full picture.
class MatchState {
  final RulesetDefinition ruleset;
  final List<int> scores;
  RoundWind wind;
  int roundNumber; // 1-3 within [wind].
  int honba;
  int dealerIndex;
  bool isOver;

  /// [startingScores] defaults to [ruleset]'s own declared `startingPoints`
  /// toggle (see its `toggleSchema`/`resolveConfig`, e.g. 35000 for
  /// SixKaSixPeiSanmaRuleset) applied to every seat, honoring [config]'s
  /// override if it sets one — falling back to a bare 25000 only if the
  /// ruleset declares no such toggle at all.
  MatchState({
    required this.ruleset,
    List<int>? startingScores,
    Map<String, Object?> config = const {},
    this.wind = RoundWind.east,
    this.roundNumber = 1,
    this.honba = 0,
    this.dealerIndex = 0,
    this.isOver = false,
  }) : scores = List.of(startingScores ??
            List.filled(
              ruleset.playerCount,
              (ruleset.resolveConfig(config)['startingPoints'] as int?) ?? 25000,
            ));

  /// E.g. "東1局" or "南3局 2本場".
  String get roundLabel {
    final windLabel = wind == RoundWind.east ? '東' : '南';
    final honbaSuffix = honba > 0 ? ' $honba本場' : '';
    return '$windLabel$roundNumber局$honbaSuffix';
  }

  /// Deals a fresh [GameState] for the current 局 — [dealerIndex] is this
  /// [MatchState]'s current dealer, not necessarily player 0.
  GameState dealCurrentRound({required Random random, required Map<String, Object?> config}) {
    return ruleset.deal(random: random, dealerIndex: dealerIndex, config: config);
  }

  /// Applies [finishedState]'s result (must have [GameState.isOver] true)
  /// to [scores], then advances [wind]/[roundNumber]/[honba]/[dealerIndex]
  /// for the next 局 — or sets [isOver] once 南3局 finishes without the
  /// dealer repeating (the traditional 半荘 endpoint).
  void advance(GameState finishedState) {
    final result = finishedState.result;
    if (result == null) {
      throw StateError('cannot advance a match on a round that has not ended');
    }

    final dealerRepeats = switch (result.reason) {
      RoundOverReason.tsumo => result.winnerIndex == dealerIndex,
      RoundOverReason.ron => result.winnerIndex == dealerIndex,
      RoundOverReason.exhaustiveDraw =>
        overallShanten(finishedState.hands[dealerIndex]) == 0,
    };

    switch (result.reason) {
      case RoundOverReason.tsumo:
        _applyTsumo(finishedState, result.winnerIndex!);
      case RoundOverReason.ron:
        _applyRon(finishedState, result.winnerIndex!, result.dealtInIndex!);
      case RoundOverReason.exhaustiveDraw:
        break; // no tenpai/noten payment yet — see class doc.
    }

    // A dealer win or any draw keeps/grows honba; a non-dealer win resets
    // it, since the dealership is genuinely changing hands.
    final nonDealerWon =
        (result.reason == RoundOverReason.tsumo || result.reason == RoundOverReason.ron) &&
            result.winnerIndex != dealerIndex;
    honba = nonDealerWon ? 0 : honba + 1;

    if (dealerRepeats) return; // same dealer, same wind/round — just honba changed above.

    // Every non-repeat hand moves the deal to the next seat and advances
    // the round number together — one seat dealing once *is* one 局.
    dealerIndex = (dealerIndex + 1) % ruleset.playerCount;
    roundNumber++;
    if (roundNumber <= ruleset.playerCount) return; // still partway through this wind.

    if (wind == RoundWind.east) {
      wind = RoundWind.south;
      roundNumber = 1;
    } else {
      isOver = true; // finished 南's last round without the dealer repeating.
    }
  }

  void _applyTsumo(GameState state, int winner) {
    final points = ruleset.scoreWin(
      hand: state.hands[winner],
      winnerIsDealer: winner == dealerIndex,
      method: WinMethod.tsumo,
    );
    for (var player = 0; player < scores.length; player++) {
      if (player == winner) continue;
      final isDealerSeat = player == dealerIndex;
      final payment = winner == dealerIndex || isDealerSeat ? points.tsumoDoubleShare : points.tsumoSingleShare;
      scores[player] -= payment;
      scores[winner] += payment;
    }
  }

  void _applyRon(GameState state, int winner, int dealtIn) {
    // Unlike tsumo, GameState.declareRon never adds the discarded tile to
    // the winner's hand (it stays a historical record in the discarder's
    // pile) — score against a reconstructed complete hand, same as the
    // single-round UI's own result banner does.
    final winnerHand = state.hands[winner];
    final winningTile = state.discardPiles[dealtIn].last;
    final completeHand = Hand(
      concealedTiles: [...winnerHand.concealedTiles, winningTile],
      melds: winnerHand.melds,
    );
    final points = ruleset.scoreWin(
      hand: completeHand,
      winnerIsDealer: winner == dealerIndex,
      method: WinMethod.ron,
    );
    scores[dealtIn] -= points.ronPayment;
    scores[winner] += points.ronPayment;
  }
}
