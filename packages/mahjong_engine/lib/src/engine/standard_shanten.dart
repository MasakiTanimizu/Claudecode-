/// Standard-hand (4 melds + pair) shanten calculation (STEP10 実装).
///
/// Unlike `kokushiShanten`/`chiitoitsuShanten`, this shape has no closed-form
/// formula: it requires searching how the concealed tiles best decompose
/// into complete melds, partial (2-tile) proto-melds, and a head pair. The
/// approach here is the standard one used by most shanten calculators:
/// decompose each suit/kind independently (tries every way to carve up that
/// kind's tiles into triplets/sequences/pairs/partials/waste), then combine
/// suits with a small knapsack-style merge that tracks, for every
/// (melds-so-far, pair-reserved?) pair, the best partials total achievable
/// — and finally take the minimum shanten over every reachable combination.
///
/// 北 (kita) tiles are excluded entirely: STEP5「北の扱い改定」makes a
/// kept-北 tile usable only for 国士無双/字一色/四喜和, never a standard hand,
/// so it can never contribute to a meld, partial, or pair here.
library;

import '../core/hand.dart';
import '../core/meld.dart';
import '../core/tile.dart';

typedef _Combo = (int melds, bool pair);

Map<_Combo, int> _decomposeRunSuit(List<int> counts) {
  final results = <_Combo, int>{};

  void recurse(List<int> c, int i, int melds, int partials, bool pair) {
    if (i > 9) {
      final key = (melds, pair);
      final existing = results[key];
      if (existing == null || existing < partials) results[key] = partials;
      return;
    }
    if (c[i] == 0) {
      recurse(c, i + 1, melds, partials, pair);
      return;
    }

    if (c[i] >= 3) {
      recurse(List<int>.of(c)..[i] -= 3, i, melds + 1, partials, pair);
    }
    if (i <= 7 && c[i] >= 1 && c[i + 1] >= 1 && c[i + 2] >= 1) {
      recurse(
        List<int>.of(c)
          ..[i] -= 1
          ..[i + 1] -= 1
          ..[i + 2] -= 1,
        i,
        melds + 1,
        partials,
        pair,
      );
    }
    if (c[i] >= 2) {
      final next = List<int>.of(c)..[i] -= 2;
      if (!pair) recurse(next, i, melds, partials, true);
      recurse(next, i, melds, partials + 1, pair);
    }
    if (i <= 8 && c[i] >= 1 && c[i + 1] >= 1) {
      recurse(
        List<int>.of(c)
          ..[i] -= 1
          ..[i + 1] -= 1,
        i,
        melds,
        partials + 1,
        pair,
      );
    }
    if (i <= 7 && c[i] >= 1 && c[i + 2] >= 1) {
      recurse(
        List<int>.of(c)
          ..[i] -= 1
          ..[i + 2] -= 1,
        i,
        melds,
        partials + 1,
        pair,
      );
    }
    recurse(List<int>.of(c)..[i] -= 1, i, melds, partials, pair);
  }

  recurse(List<int>.of(counts), 1, 0, 0, false);
  return results;
}

Map<_Combo, int> _decomposeSingleKind(int count) {
  final results = <_Combo, int>{};

  void recurse(int remaining, int melds, int partials, bool pair) {
    if (remaining == 0) {
      final key = (melds, pair);
      final existing = results[key];
      if (existing == null || existing < partials) results[key] = partials;
      return;
    }
    if (remaining >= 3) {
      recurse(remaining - 3, melds + 1, partials, pair);
    }
    if (remaining >= 2) {
      if (!pair) recurse(remaining - 2, melds, partials, true);
      recurse(remaining - 2, melds, partials + 1, pair);
    }
    recurse(remaining - 1, melds, partials, pair);
  }

  recurse(count, 0, 0, false);
  return results;
}

Map<_Combo, int> _merge(Map<_Combo, int> a, Map<_Combo, int> b) {
  final merged = <_Combo, int>{};
  for (final ea in a.entries) {
    for (final eb in b.entries) {
      final key = (ea.key.$1 + eb.key.$1, ea.key.$2 || eb.key.$2);
      final value = ea.value + eb.value;
      final existing = merged[key];
      if (existing == null || existing < value) merged[key] = value;
    }
  }
  return merged;
}

/// Shanten toward a standard (4 melds + pair) hand. -1 means already
/// complete, 0 means tenpai. Open melds (`hand.melds`) count directly as
/// complete melds — unlike kokushi/chiitoitsu, a standard hand has no
/// menzen requirement.
int standardShanten(Hand hand) {
  final pinCounts = List<int>.filled(10, 0);
  final souCounts = List<int>.filled(10, 0);
  var man1 = 0, man9 = 0;
  var east = 0, south = 0, west = 0;
  var white = 0, green = 0, red = 0;

  for (final tile in hand.concealedTiles) {
    switch (tile) {
      case NumberTile t when t.suit == NumberSuit.pin:
        pinCounts[t.number]++;
      case NumberTile t when t.suit == NumberSuit.sou:
        souCounts[t.number]++;
      case NumberTile t when t.suit == NumberSuit.man && t.number == 1:
        man1++;
      case NumberTile t when t.suit == NumberSuit.man && t.number == 9:
        man9++;
      case NumberTile _:
        break; // unreachable given NumberTile's own constructor asserts.
      case WindTile t when t.wind == Wind.east:
        east++;
      case WindTile t when t.wind == Wind.south:
        south++;
      case WindTile _:
        west++;
      case DragonTile t when t.dragon == Dragon.white:
        white++;
      case DragonTile t when t.dragon == Dragon.green:
        green++;
      case DragonTile _:
        red++;
      case KitaTile _:
        break; // never usable in a standard hand (STEP5).
      case HanaTile _:
        break; // extracted 華牌 never sit in a live hand; ignore defensively.
    }
  }

  var merged = <_Combo, int>{(0, false): 0};
  merged = _merge(merged, _decomposeRunSuit(pinCounts));
  merged = _merge(merged, _decomposeRunSuit(souCounts));
  for (final count in [man1, man9, east, south, west, white, green, red]) {
    merged = _merge(merged, _decomposeSingleKind(count));
  }

  final fixedMelds = hand.melds.where((m) => m.kind != MeldKind.pair).length;

  var best = 8; // worst case: no melds, no partials, no pair.
  for (final entry in merged.entries) {
    final rawMelds = fixedMelds + entry.key.$1;
    final melds = rawMelds > 4 ? 4 : rawMelds;
    final hasPair = entry.key.$2;
    final partialsCap = 4 - melds;
    final partialsUsed = entry.value > partialsCap ? partialsCap : entry.value;
    final shanten = 8 - 2 * melds - partialsUsed - (hasPair ? 1 : 0);
    if (shanten < best) best = shanten;
  }
  return best;
}
