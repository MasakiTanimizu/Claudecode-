/// Declared, ruleset-specific settings (STEP5「ルールセット抽象化」
/// `toggleSchema`; STEP3 `rule_settings.config` / `matches.rule_config` are
/// jsonb blobs shaped by this schema).
library;

enum RuleToggleType { boolean, choice, integer }

/// One configurable rule, self-describing enough for a settings screen to
/// render without ruleset-specific UI code (STEP7 設定画面).
class RuleToggleDescriptor {
  final String key;
  final String label;
  final RuleToggleType type;
  final Object defaultValue;

  /// For [RuleToggleType.choice] only: the allowed values.
  final List<String>? choices;

  const RuleToggleDescriptor({
    required this.key,
    required this.label,
    required this.type,
    required this.defaultValue,
    this.choices,
  });
}
