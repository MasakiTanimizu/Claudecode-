import 'dart:math';

import 'package:mahjong_engine/mahjong_engine.dart';
import 'package:test/test.dart';

NumberTile pin(int n) => NumberTile(NumberSuit.pin, n);

void main() {
  group('RulesetRegistry', () {
    test('resolves the built-in six_ka_six_pei_sanma ruleset by key', () {
      final ruleset = RulesetRegistry.resolve('sanma.six_ka_six_pei');
      expect(ruleset, isA<SixKaSixPeiSanmaRuleset>());
      expect(ruleset.rulesetKey, 'sanma.six_ka_six_pei');
      expect(ruleset.playerCount, 3);
    });

    test('find returns null for an unregistered key', () {
      expect(RulesetRegistry.find('sanma.does_not_exist'), isNull);
    });

    test('resolve throws for an unregistered key', () {
      expect(() => RulesetRegistry.resolve('sanma.does_not_exist'), throwsArgumentError);
    });

    test('all lists every registered ruleset', () {
      expect(RulesetRegistry.all, contains(isA<SixKaSixPeiSanmaRuleset>()));
    });
  });

  group('SixKaSixPeiSanmaRuleset', () {
    final ruleset = SixKaSixPeiSanmaRuleset();

    test('resolveConfig fills in declared defaults', () {
      final resolved = ruleset.resolveConfig(const {});
      expect(resolved['doraMarkPreset'], 'allRed');
      expect(resolved['kitaDoraEnabled'], true);
      expect(resolved['gameType'], 'tonpuusen');
      expect(resolved['startingPoints'], 35000);
    });

    test('resolveConfig keeps caller-provided overrides', () {
      final resolved = ruleset.resolveConfig(const {'doraMarkPreset': 'oneRedOneBlue'});
      expect(resolved['doraMarkPreset'], 'oneRedOneBlue');
      expect(resolved['kitaDoraEnabled'], true); // still defaulted.
    });

    test('buildTileSet honors the doraMarkPreset toggle', () {
      final allRed = ruleset.buildTileSet(const {});
      expect(allRed, hasLength(totalTileCount));
      expect(allRed.whereType<NumberTile>().where((t) => t.mark == TileMark.red), hasLength(8));

      final mixed = ruleset.buildTileSet(const {'doraMarkPreset': 'oneRedOneBlue'});
      expect(mixed.whereType<NumberTile>().where((t) => t.mark == TileMark.red), hasLength(2));
      expect(mixed.whereType<NumberTile>().where((t) => t.mark == TileMark.blue), hasLength(2));
    });

    test('deal produces a ready-to-play 3-player round', () {
      final state = ruleset.deal(random: Random(1), dealerIndex: 1, config: const {});
      expect(state.hands, hasLength(3));
      for (final hand in state.hands) {
        expect(hand.concealedTiles, hasLength(13));
      }
      expect(state.currentPlayerIndex, 1);
      expect(state.phase, TurnPhase.awaitingDraw);
    });

    test('scoreWin delegates to the shared scoring logic', () {
      final chiitoitsu = Hand(concealedTiles: [
        for (var n = 1; n <= 7; n++) ...[pin(n), pin(n)],
      ]);
      final points = ruleset.scoreWin(hand: chiitoitsu, winnerIsDealer: false, method: WinMethod.ron);
      expect(
        points,
        const WinPoints(ronPayment: 2000, tsumoDoubleShare: 1000, tsumoSingleShare: 1000),
      );
    });
  });
}
