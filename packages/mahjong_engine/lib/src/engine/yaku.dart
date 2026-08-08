/// Closed-form yaku detection (STEP10 実装).
///
/// Scoped to yaku decidable from tile shape alone, independent of game
/// context (riichi state, seat/round wind, who discarded what). Everything
/// else in STEP5's 採用役一覧 needs a melds decomposition and/or table
/// state and is deferred alongside the standard-hand shanten algorithm.
library;

import '../core/hand.dart';
import '../core/tile.dart';
import 'shanten.dart';

enum ClosedFormYaku {
  kokushiMusou,
  chiitoitsu,
  chiitoitsuYonmai,
  chiitoitsuHachimai,
}

/// True for a complete (14-tile, fully concealed) 国士無双 hand.
bool isKokushiMusou(Hand hand) =>
    hand.melds.isEmpty &&
    hand.concealedTiles.length == 14 &&
    kokushiShanten(hand) == -1;

/// Which 七対子 variant [hand] completes as, or `null` if it doesn't
/// complete any of them. 北 tiles can never form a chiitoitsu pair (STEP5
/// 「北の扱い改定」), and any declared meld — including ankan — breaks the
/// shape entirely (STEP5「対象を暗槓すると通常の面子構成に変わり、この役は
/// 失われる」).
ClosedFormYaku? chiitoitsuVariant(Hand hand) {
  if (hand.melds.isNotEmpty) return null;
  final tiles = hand.concealedTiles;
  if (tiles.length != 14) return null;
  if (tiles.any((tile) => tile.tileKind == KitaTile)) return null;

  final counts = <Object, int>{};
  for (final tile in tiles) {
    counts[tile.tileKind] = (counts[tile.tileKind] ?? 0) + 1;
  }
  // Any kind held 1 or 3 times (or 5+) can't be part of any pair/quad shape.
  if (counts.values.any((count) => count != 2 && count != 4)) return null;

  final quadKinds = counts.values.where((count) => count == 4).length;
  final pairKinds = counts.length - quadKinds;
  return switch ((quadKinds, pairKinds)) {
    (0, 7) => ClosedFormYaku.chiitoitsu,
    (1, 5) => ClosedFormYaku.chiitoitsuYonmai,
    (2, 3) => ClosedFormYaku.chiitoitsuHachimai,
    _ => null,
  };
}

/// All closed-form yaku [hand] completes as. 国士無双 and every 七対子
/// variant are mutually exclusive by shape, so this holds at most one
/// element — it returns a list for a uniform call site alongside future
/// melds-based yaku detection, which can hold several at once.
List<ClosedFormYaku> detectClosedFormYaku(Hand hand) {
  if (isKokushiMusou(hand)) return const [ClosedFormYaku.kokushiMusou];
  final chiitoitsu = chiitoitsuVariant(hand);
  return chiitoitsu == null ? const [] : [chiitoitsu];
}
