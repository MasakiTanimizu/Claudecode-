/// Shanten (テンパイまでの距離) calculators (STEP10 実装).
///
/// Only the two closed-form shapes are implemented here. Standard-hand
/// (4 melds + pair) shanten needs a real search/decomposition algorithm and
/// is deliberately deferred to its own slice rather than mixed in here.
library;

import '../core/hand.dart';
import '../core/tile.dart';

/// The 13 tile kinds that count toward 国士無双 in this ruleset: the six
/// terminals, the three winds, the three dragons, and 北 — which is
/// hand-holdable only for this yaku (and 字一色/四喜和) per STEP5「北の扱い改定」.
final Set<Object> _kokushiKinds = {
  (NumberSuit.man, 1),
  (NumberSuit.man, 9),
  (NumberSuit.pin, 1),
  (NumberSuit.pin, 9),
  (NumberSuit.sou, 1),
  (NumberSuit.sou, 9),
  Wind.east,
  Wind.south,
  Wind.west,
  Dragon.white,
  Dragon.green,
  Dragon.red,
  KitaTile,
};

/// 国士無双 shanten: `13 - (distinct kokushi kinds present) - (1 if any of
/// them is paired)`. Kokushi must be fully concealed, so a hand with any
/// meld (even ankan) is treated as maximally far (13).
int kokushiShanten(Hand hand) {
  if (hand.melds.isNotEmpty) return 13;

  final counts = <Object, int>{};
  for (final tile in hand.concealedTiles) {
    final kind = tile.tileKind;
    if (_kokushiKinds.contains(kind)) {
      counts[kind] = (counts[kind] ?? 0) + 1;
    }
  }

  final distinctKinds = counts.length;
  final hasPair = counts.values.any((count) => count >= 2);
  return 13 - distinctKinds - (hasPair ? 1 : 0);
}

/// 七対子 shanten: `6 - pairCount + max(0, 7 - kindCount)`. 北 is excluded
/// from the count — kept-北 tiles are only usable for 国士無双/字一色/四喜和
/// (STEP5「北の扱い改定」), never as a chiitoitsu pair. Melded hands can't
/// form chiitoitsu at all, so they're treated as maximally far (6). This
/// intentionally does not special-case the STEP5追補2 4枚/8枚 chiitoitsu
/// variants — those are a scoring-time distinction, not a shanten one.
int chiitoitsuShanten(Hand hand) {
  if (hand.melds.isNotEmpty) return 6;

  final counts = <Object, int>{};
  for (final tile in hand.concealedTiles) {
    final kind = tile.tileKind;
    if (kind == KitaTile) continue;
    counts[kind] = (counts[kind] ?? 0) + 1;
  }

  final pairCount = counts.values.where((count) => count >= 2).length;
  final kindCount = counts.length;
  final varietyPenalty = kindCount < 7 ? 7 - kindCount : 0;
  return 6 - pairCount + varietyPenalty;
}
