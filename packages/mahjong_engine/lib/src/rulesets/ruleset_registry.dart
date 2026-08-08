/// Resolves a `ruleset_key` to its `RulesetDefinition` (STEP5「複数ルールセッ
/// ト対応」/ STEP3 `matches.ruleset_key`). CPU AI, client UI, and
/// server-side authoritative validation all go through this registry
/// rather than importing a specific ruleset directly, so a new ruleset
/// only needs to register itself here — no other layer changes.
library;

import 'ruleset_definition.dart';
import 'six_ka_six_pei_sanma/six_ka_six_pei_sanma_ruleset.dart';

class RulesetRegistry {
  RulesetRegistry._();

  static final List<RulesetDefinition> _builtIn = [SixKaSixPeiSanmaRuleset()];

  static final Map<String, RulesetDefinition> _byKey = {
    for (final ruleset in _builtIn) ruleset.rulesetKey: ruleset,
  };

  /// All registered rulesets.
  static List<RulesetDefinition> get all => List.unmodifiable(_byKey.values);

  /// The ruleset for [rulesetKey], or `null` if none is registered.
  static RulesetDefinition? find(String rulesetKey) => _byKey[rulesetKey];

  /// The ruleset for [rulesetKey]. Throws [ArgumentError] if none is
  /// registered — callers that already validated the key (e.g. reading it
  /// back from a stored match) can use this directly instead of null-
  /// checking [find] again.
  static RulesetDefinition resolve(String rulesetKey) {
    final ruleset = find(rulesetKey);
    if (ruleset == null) {
      throw ArgumentError.value(rulesetKey, 'rulesetKey', 'no ruleset registered with this key');
    }
    return ruleset;
  }
}
