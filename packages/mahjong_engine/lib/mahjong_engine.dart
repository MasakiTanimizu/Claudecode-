/// Pure-Dart mahjong rules engine shared by the Flutter client and the
/// Serverpod server (STEP1/STEP2, docs/design). No Flutter or Serverpod
/// dependency here — see docs/design/01-tech-stack.md for why.
library;

export 'src/ai/call_decision.dart';
export 'src/ai/danger.dart';
export 'src/ai/danger_aware_discard.dart';
export 'src/ai/difficulty.dart';
export 'src/ai/heuristic_discard.dart';
export 'src/ai/kita_decision.dart';
export 'src/ai/ukeire.dart';
export 'src/core/hand.dart';
export 'src/core/meld.dart';
export 'src/core/tile.dart';
export 'src/core/tile_set.dart';
export 'src/core/wall.dart';
export 'src/engine/game_state.dart';
export 'src/engine/overall_shanten.dart';
export 'src/engine/scoring.dart';
export 'src/engine/shanten.dart';
export 'src/engine/standard_shanten.dart';
export 'src/engine/standard_yaku.dart';
export 'src/engine/yaku.dart';
export 'src/rulesets/rule_toggle.dart';
export 'src/rulesets/ruleset_definition.dart';
export 'src/rulesets/ruleset_registry.dart';
export 'src/rulesets/six_ka_six_pei_sanma/six_ka_six_pei_sanma_ruleset.dart';
