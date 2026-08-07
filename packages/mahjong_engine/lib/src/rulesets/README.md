# rulesets/

新しいルールセットを追加するときは、このディレクトリの下に1つサブディレクトリを作り、`RulesetDefinition`を実装して`ruleset_registry`に登録する（`docs/design` STEP5補遺「複数ルールセット対応のための抽象化」参照）。既存のルールセットには手を入れない。

- `six_ka_six_pei_sanma/` — 1つ目のルールセット。「6華6北5等三麻」。仕様は`docs/design`のSTEP5〜STEP5追補6に確定済み
