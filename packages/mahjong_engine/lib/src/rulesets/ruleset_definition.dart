/// The pluggable-ruleset abstraction (STEP5「ルールセット抽象化」/ STEP6
/// `rulesets/`).
///
/// A `RulesetDefinition` is a facade, not a reimplementation: the actual
/// tile model, shanten/yaku detection, and scoring already live in `core/`
/// and `engine/` as concrete, SixKa6PeiSanma-shaped code (STEP5's own note
/// that a new ruleset gets its own directory rather than sharing a fully
/// generic engine — this ruleset's tiles are genuinely structurally
/// different from a standard 4-player set, so there's little to gain by
/// forcing a shared abstract tile/meld/yaku layer). What *is* shared and
/// worth abstracting is the entry points every other layer (CPU AI, client
/// UI, server-side authoritative validation) needs without caring which
/// ruleset it's talking to: build the tile set, deal a round, score a win,
/// and describe the configurable toggles for a settings screen.
library;

import 'dart:math';

import '../core/hand.dart';
import '../core/tile.dart';
import '../engine/game_state.dart';
import '../engine/scoring.dart';
import 'rule_toggle.dart';

abstract class RulesetDefinition {
  /// Unique ID (STEP3 `rule_settings.ruleset_key` / `matches.ruleset_key`).
  String get rulesetKey;

  String get displayName;

  /// 3 or 4 (STEP6「四人麻雀への将来拡張」— `core`/`engine` don't hardcode
  /// player count, so a future 4-player ruleset can report 4 here).
  int get playerCount;

  /// This ruleset's configurable settings, self-describing enough for a
  /// settings screen to render generically (STEP7).
  List<RuleToggleDescriptor> get toggleSchema;

  /// Fills in any keys missing from [config] with this ruleset's declared
  /// defaults — callers (and STEP3's `rule_settings`/`matches` storage)
  /// only need to carry the values a user actually changed.
  Map<String, Object?> resolveConfig(Map<String, Object?> config) {
    final resolved = Map<String, Object?>.of(config);
    for (final toggle in toggleSchema) {
      resolved.putIfAbsent(toggle.key, () => toggle.defaultValue);
    }
    return resolved;
  }

  /// The full physical tile set for a new match, honoring [config]'s
  /// ruleset-specific toggles (e.g. a dora mark preset).
  List<Tile> buildTileSet(Map<String, Object?> config);

  /// Deals a fresh, ready-to-play [GameState] for one 局.
  GameState deal({
    required Random random,
    required int dealerIndex,
    required Map<String, Object?> config,
  });

  /// Points for a completed win.
  WinPoints scoreWin({
    required Hand hand,
    required bool winnerIsDealer,
    required WinMethod method,
  });
}
