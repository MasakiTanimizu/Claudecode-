/// 「6華6北5等三麻」— the first (and so far only) `RulesetDefinition`. Do
/// not extend this file's scope with unrelated rules; a *new* ruleset gets
/// its own directory under `rulesets/` instead (STEP5「複数ルールセット対応」).
library;

import 'dart:math';

import '../../core/hand.dart';
import '../../core/tile.dart';
import '../../core/tile_set.dart';
import '../../engine/game_state.dart';
import '../../engine/scoring.dart';
import '../rule_toggle.dart';
import '../ruleset_definition.dart';

class SixKaSixPeiSanmaRuleset extends RulesetDefinition {
  @override
  String get rulesetKey => 'sanma.six_ka_six_pei';

  @override
  String get displayName => '6華6北5等三麻';

  @override
  int get playerCount => 3;

  @override
  List<RuleToggleDescriptor> get toggleSchema => const [
        RuleToggleDescriptor(
          key: 'doraMarkPreset',
          label: '赤ドラ・青ドラ',
          type: RuleToggleType.choice,
          defaultValue: 'allRed',
          choices: ['allRed', 'oneRedOneBlue'],
        ),
        RuleToggleDescriptor(
          key: 'kitaDoraEnabled',
          label: '北ドラ',
          type: RuleToggleType.boolean,
          defaultValue: true,
        ),
        RuleToggleDescriptor(
          key: 'openTanyaoEnabled',
          label: '食いタン',
          type: RuleToggleType.boolean,
          defaultValue: true,
        ),
        RuleToggleDescriptor(
          key: 'atozukeEnabled',
          label: '後付け',
          type: RuleToggleType.boolean,
          defaultValue: true,
        ),
        RuleToggleDescriptor(
          key: 'ippatsuEnabled',
          label: '一発',
          type: RuleToggleType.boolean,
          defaultValue: true,
        ),
        RuleToggleDescriptor(
          key: 'doubleRiichiEnabled',
          label: 'ダブル立直',
          type: RuleToggleType.boolean,
          defaultValue: true,
        ),
        RuleToggleDescriptor(
          key: 'gameType',
          label: '対局形式',
          type: RuleToggleType.choice,
          defaultValue: 'tonpuusen',
          choices: ['tonpuusen', 'hanchan'],
        ),
        RuleToggleDescriptor(
          key: 'bustEndEnabled',
          label: '飛び終了',
          type: RuleToggleType.boolean,
          defaultValue: true,
        ),
        RuleToggleDescriptor(
          key: 'extensionEnabled',
          label: '延長戦',
          type: RuleToggleType.boolean,
          defaultValue: false,
        ),
        RuleToggleDescriptor(
          key: 'startingPoints',
          label: '持ち点',
          type: RuleToggleType.integer,
          defaultValue: 35000,
        ),
        RuleToggleDescriptor(
          key: 'returnPoints',
          label: '返し点',
          type: RuleToggleType.integer,
          defaultValue: 40000,
        ),
      ];

  @override
  List<Tile> buildTileSet(Map<String, Object?> config) {
    final presetName = resolveConfig(config)['doraMarkPreset'] as String;
    return buildFullTileSet(markPreset: DoraMarkPreset.values.byName(presetName));
  }

  @override
  GameState deal({
    required Random random,
    required int dealerIndex,
    required Map<String, Object?> config,
  }) {
    return GameState.deal(
      fullTileSet: buildTileSet(config),
      playerCount: playerCount,
      random: random,
      dealerIndex: dealerIndex,
    );
  }

  @override
  WinPoints scoreWin({
    required Hand hand,
    required bool winnerIsDealer,
    required WinMethod method,
  }) {
    return calculateWinPoints(hand: hand, winnerIsDealer: winnerIsDealer, method: method);
  }
}
