/// Standard-hand (4 melds + pair) decomposition and shape-based yaku
/// detection (STEP10 実装, docs/design/05「採用役一覧」).
///
/// Scoped like the rest of `engine/`: only yaku decidable from the hand's
/// own shape and meld sources (concealed vs. open), independent of table
/// context (seat/round wind, riichi state, turn-order events). That rules
/// out 役牌（自風・場風）, 平和 (needs the actual wait shape, not just the
/// completed tiles), 立直/一発/嶺上開花/槍槓/海底/河底, and the game-start
/// yaku (天和/地和/人和/流し役満). Those need a `GameContext` layer that
/// doesn't exist yet.
///
/// 北 (kita) tiles are excluded from decomposition entirely, same as
/// `standard_shanten.dart` — so 字一色 here only covers honor-only hands
/// with zero 北 involved, and 四喜和 (which STEP5 lets 北 fill in as a
/// stand-in 4th wind) isn't covered at all. Both need 北-aware
/// decomposition, deferred alongside `standardShanten`'s own scope note.
library;

import '../core/hand.dart';
import '../core/meld.dart';
import '../core/tile.dart';

sealed class HandGroup {}

class SequenceGroup implements HandGroup {
  final NumberSuit suit;
  final int start; // e.g. 1 means the 1-2-3 run.
  final bool isOpen;
  const SequenceGroup(this.suit, this.start, {required this.isOpen});
}

class SetGroup implements HandGroup {
  /// A tileKind: `(NumberSuit, int)` for a number tile, or a [Wind]/[Dragon]
  /// value for an honor tile.
  final Object kind;
  final int tileCount; // 3 (kotsu) or 4 (kantsu).
  final bool isOpen;
  const SetGroup(this.kind, this.tileCount, {required this.isOpen});
}

class PairGroup {
  final Object kind;
  const PairGroup(this.kind);
}

class StandardDecomposition {
  /// Exactly 4 melds (open + concealed, sequences + sets).
  final List<HandGroup> melds;
  final PairGroup pair;
  const StandardDecomposition(this.melds, this.pair);
}

enum StandardYaku {
  tanyao,
  yakuhaiWhite,
  yakuhaiGreen,
  yakuhaiRed,
  toitoi,
  sanankou,
  sankantsu,
  honroutou,
  shousangen,
  chanta,
  ittsuu,
  junchan,
  honitsu,
  chinitsu,
  suuankou,
  daisangen,
  chinroutou,
  suukantsu,
  tsuiisou,
}

bool _isHonorKind(Object kind) => kind is Wind || kind is Dragon;

bool _isTerminalKind(Object kind) {
  if (_isHonorKind(kind)) return false;
  final (_, rank) = kind as (NumberSuit, int);
  return rank == 1 || rank == 9;
}

typedef _GroupOptions = List<(List<HandGroup> melds, Object? pairKind)>;

_GroupOptions _completeRunSuit(NumberSuit suit, List<int> counts) {
  final results = <(List<HandGroup>, Object?)>[];

  void recurse(List<int> c, int i, List<HandGroup> melds, Object? pairKind) {
    if (i > 9) {
      results.add((melds, pairKind));
      return;
    }
    if (c[i] == 0) {
      recurse(c, i + 1, melds, pairKind);
      return;
    }
    if (c[i] >= 3) {
      recurse(
        List<int>.of(c)..[i] -= 3,
        i,
        [...melds, SetGroup((suit, i), 3, isOpen: false)],
        pairKind,
      );
    }
    if (i <= 7 && c[i] >= 1 && c[i + 1] >= 1 && c[i + 2] >= 1) {
      recurse(
        List<int>.of(c)
          ..[i] -= 1
          ..[i + 1] -= 1
          ..[i + 2] -= 1,
        i,
        [...melds, SequenceGroup(suit, i, isOpen: false)],
        pairKind,
      );
    }
    if (c[i] >= 2 && pairKind == null) {
      recurse(List<int>.of(c)..[i] -= 2, i, melds, (suit, i));
    }
  }

  recurse(List<int>.of(counts), 1, const [], null);
  return results;
}

_GroupOptions _completeSingleKind(Object kind, int count) {
  final results = <(List<HandGroup>, Object?)>[];

  void recurse(int remaining, List<HandGroup> melds, Object? pairKind) {
    if (remaining == 0) {
      results.add((melds, pairKind));
      return;
    }
    if (remaining >= 3) {
      recurse(remaining - 3, [...melds, SetGroup(kind, 3, isOpen: false)], pairKind);
    }
    if (remaining >= 2 && pairKind == null) {
      recurse(remaining - 2, melds, kind);
    }
  }

  recurse(count, const [], null);
  return results;
}

HandGroup _groupFromDeclaredMeld(Meld meld) {
  if (meld.kind == MeldKind.shuntsu) {
    final numbers = meld.tiles.cast<NumberTile>().toList()
      ..sort((a, b) => a.number.compareTo(b.number));
    return SequenceGroup(numbers.first.suit, numbers.first.number, isOpen: meld.isOpen);
  }
  return SetGroup(meld.tiles.first.tileKind, meld.tiles.length, isOpen: meld.isOpen);
}

/// Every way [hand] can complete as a standard (4 melds + pair) shape.
/// Empty if it doesn't complete this shape at all (e.g. it's mid-hand, or
/// it only completes as 国士無双/七対子 — see `yaku.dart` for those).
List<StandardDecomposition> decomposeStandardHand(Hand hand) {
  // A declared 北 ankan can never be part of a standard hand (STEP5) — bail
  // out rather than let _groupFromDeclaredMeld hit a tileKind it can't
  // classify as a number or honor kind.
  if (hand.melds.any((m) => m.tiles.any((t) => t is KitaTile))) {
    return const [];
  }

  final declaredMelds = hand.melds.where((m) => m.kind != MeldKind.pair).map(_groupFromDeclaredMeld).toList();

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
        break;
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
        break;
    }
  }

  var combos = <(List<HandGroup>, Object?)>[(const [], null)];
  void fold(_GroupOptions options) {
    final next = <(List<HandGroup>, Object?)>[];
    for (final combo in combos) {
      for (final option in options) {
        if (combo.$2 != null && option.$2 != null) continue;
        final melds = [...combo.$1, ...option.$1];
        if (melds.length + declaredMelds.length > 4) continue;
        next.add((melds, combo.$2 ?? option.$2));
      }
    }
    combos = next;
  }

  fold(_completeRunSuit(NumberSuit.pin, pinCounts));
  fold(_completeRunSuit(NumberSuit.sou, souCounts));
  fold(_completeSingleKind((NumberSuit.man, 1), man1));
  fold(_completeSingleKind((NumberSuit.man, 9), man9));
  fold(_completeSingleKind(Wind.east, east));
  fold(_completeSingleKind(Wind.south, south));
  fold(_completeSingleKind(Wind.west, west));
  fold(_completeSingleKind(Dragon.white, white));
  fold(_completeSingleKind(Dragon.green, green));
  fold(_completeSingleKind(Dragon.red, red));

  final results = <StandardDecomposition>[];
  for (final combo in combos) {
    final totalMelds = combo.$1.length + declaredMelds.length;
    if (totalMelds != 4 || combo.$2 == null) continue;
    results.add(StandardDecomposition([...declaredMelds, ...combo.$1], PairGroup(combo.$2!)));
  }
  return results;
}

bool _chantaOk(Iterable<Object> allKinds, Iterable<SequenceGroup> sequences) {
  for (final s in sequences) {
    if (s.start != 1 && s.start != 7) return false;
  }
  for (final kind in allKinds) {
    if (!(_isTerminalKind(kind) || _isHonorKind(kind))) return false;
  }
  return true;
}

bool _junchanOk(Iterable<Object> allKinds, Iterable<SequenceGroup> sequences) {
  for (final s in sequences) {
    if (s.start != 1 && s.start != 7) return false;
  }
  for (final kind in allKinds) {
    if (_isHonorKind(kind) || !_isTerminalKind(kind)) return false;
  }
  return true;
}

bool _isSimpleKind(Object kind) {
  if (_isHonorKind(kind)) return false;
  final (_, rank) = kind as (NumberSuit, int);
  return rank != 1 && rank != 9;
}

List<StandardYaku> _evaluate(Hand hand, StandardDecomposition decomposition) {
  final sequences = decomposition.melds.whereType<SequenceGroup>().toList();
  final sets = decomposition.melds.whereType<SetGroup>().toList();
  final setKinds = sets.map((s) => s.kind).toList();
  final allKinds = [...setKinds, decomposition.pair.kind];

  final dragonSetKinds = setKinds.whereType<Dragon>().toSet();
  final concealedSetCount = sets.where((s) => !s.isOpen).length;
  final kantsuCount = hand.melds.where((m) => m.kind == MeldKind.kantsu).length;

  final allHonor = sequences.isEmpty && allKinds.every(_isHonorKind);
  final allTerminalNoHonor = sequences.isEmpty && allKinds.every(_isTerminalKind);
  final allTerminalOrHonor =
      sequences.isEmpty && allKinds.every((k) => _isTerminalKind(k) || _isHonorKind(k));

  final yakuman = <StandardYaku>[];
  if (dragonSetKinds.length == 3) yakuman.add(StandardYaku.daisangen);
  if (concealedSetCount == 4) yakuman.add(StandardYaku.suuankou);
  if (kantsuCount >= 4) yakuman.add(StandardYaku.suukantsu);
  if (allHonor) yakuman.add(StandardYaku.tsuiisou);
  if (allTerminalNoHonor) yakuman.add(StandardYaku.chinroutou);
  if (yakuman.isNotEmpty) return yakuman;

  final result = <StandardYaku>[];

  final isTanyao = sequences.every((s) => s.start != 1 && s.start != 7) &&
      setKinds.every(_isSimpleKind) &&
      _isSimpleKind(decomposition.pair.kind);
  if (isTanyao) result.add(StandardYaku.tanyao);

  for (final kind in dragonSetKinds) {
    result.add(switch (kind) {
      Dragon.white => StandardYaku.yakuhaiWhite,
      Dragon.green => StandardYaku.yakuhaiGreen,
      Dragon.red => StandardYaku.yakuhaiRed,
    });
  }

  if (sequences.isEmpty) result.add(StandardYaku.toitoi);
  if (concealedSetCount == 3) result.add(StandardYaku.sanankou);
  if (kantsuCount == 3) result.add(StandardYaku.sankantsu);
  if (allTerminalOrHonor) result.add(StandardYaku.honroutou);

  final pairKind = decomposition.pair.kind;
  if (dragonSetKinds.length == 2 && pairKind is Dragon) {
    result.add(StandardYaku.shousangen);
  }

  if (_junchanOk(allKinds, sequences)) {
    result.add(StandardYaku.junchan);
  } else if (_chantaOk(allKinds, sequences)) {
    result.add(StandardYaku.chanta);
  }

  bool hasIttsuu(NumberSuit suit) {
    final starts = sequences.where((s) => s.suit == suit).map((s) => s.start).toSet();
    return starts.containsAll(const {1, 4, 7});
  }

  if (hasIttsuu(NumberSuit.pin) || hasIttsuu(NumberSuit.sou)) {
    result.add(StandardYaku.ittsuu);
  }

  final numberSuitsUsed = <NumberSuit>{};
  var hasHonorGroup = false;
  for (final kind in allKinds) {
    if (_isHonorKind(kind)) {
      hasHonorGroup = true;
    } else {
      numberSuitsUsed.add((kind as (NumberSuit, int)).$1);
    }
  }
  for (final s in sequences) {
    numberSuitsUsed.add(s.suit);
  }
  if (numberSuitsUsed.length == 1) {
    result.add(hasHonorGroup ? StandardYaku.honitsu : StandardYaku.chinitsu);
  }

  return result;
}

int _hanValue(StandardYaku yaku, {required bool isMenzen}) => switch (yaku) {
      StandardYaku.tanyao => 1,
      StandardYaku.yakuhaiWhite => 1,
      StandardYaku.yakuhaiGreen => 1,
      StandardYaku.yakuhaiRed => 1,
      StandardYaku.toitoi => 2,
      StandardYaku.sanankou => 2,
      StandardYaku.sankantsu => 2,
      StandardYaku.honroutou => 2,
      StandardYaku.shousangen => 2,
      StandardYaku.chanta => 2,
      StandardYaku.ittsuu => 2,
      StandardYaku.junchan => isMenzen ? 3 : 2,
      StandardYaku.honitsu => isMenzen ? 3 : 2,
      StandardYaku.chinitsu => isMenzen ? 6 : 5,
      StandardYaku.suuankou => 13,
      StandardYaku.daisangen => 13,
      StandardYaku.chinroutou => 13,
      StandardYaku.suukantsu => 13,
      StandardYaku.tsuiisou => 13,
    };

/// The best (highest-han) shape-based yaku set [hand] completes as a
/// standard hand, or an empty list if it doesn't complete this shape.
/// A hand with more than one valid decomposition (e.g. an ambiguous
/// toitoi-or-sequences shape) is scored using whichever reading wins more.
List<StandardYaku> detectStandardYaku(Hand hand) {
  final decompositions = decomposeStandardHand(hand);
  if (decompositions.isEmpty) return const [];

  var best = const <StandardYaku>[];
  var bestHan = -1;
  for (final decomposition in decompositions) {
    final yaku = _evaluate(hand, decomposition);
    final han = yaku.fold(0, (sum, y) => sum + _hanValue(y, isMenzen: hand.isMenzen));
    if (han > bestHan) {
      bestHan = han;
      best = yaku;
    }
  }
  return best;
}
