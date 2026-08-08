/// Point calculation for closed-form yaku (STEP10 実装, docs/design/05
/// 「点数計算」).
///
/// Reuses the standard 4-player fu×han point table (満貫/跳満/倍満/三倍満/
/// 役満 tiers), but with two ruleset-specific twists: 1〜3翻 uses a fixed
/// table that is deliberately independent of fu (STEP5「1〜3翻の固定点数表」
/// — a house-rule simplification, not derived from fu math), and every
/// payment rounds UP to the nearest 1000 points instead of the usual 100
/// (STEP5「点数の丸め単位」). This intentionally produces some apparent
/// "coincidences" at low han — e.g. a 1翻 non-dealer tsumo has both
/// opponents pay 1,000 even though the underlying dealer/non-dealer rates
/// differ, because both round up to the same 1,000 floor.
///
/// Covers the closed-form yaku from `yaku.dart` (国士無双, 七対子 variants)
/// and the shape-based standard-hand yaku from `standard_yaku.dart`. Fu for
/// a standard hand only covers what's decidable without a winning-tile/wait
/// context: base fu, menzen-ron/tsumo fu, per-meld fu, and a dragon-pair
/// bonus — wait-shape fu (kanchan/penchan/tanki +2, and the "ron on a
/// shanpon wait scores the completed triplet as open" exception) needs a
/// `GameContext` this layer doesn't have yet, same scope boundary as
/// `standard_yaku.dart` itself.
library;

import '../core/hand.dart';
import '../core/tile.dart';
import 'standard_yaku.dart';
import 'yaku.dart';

/// What each opponent pays for a single win.
///
/// - Ron: the discarder alone pays [ronPayment].
/// - Tsumo, winner is the dealer: BOTH other players pay [tsumoDoubleShare]
///   each ("オール").
/// - Tsumo, winner is a non-dealer: the dealer-seated opponent pays
///   [tsumoDoubleShare], and the other (non-dealer-seated) opponent pays
///   [tsumoSingleShare].
class WinPoints {
  final int ronPayment;
  final int tsumoDoubleShare;
  final int tsumoSingleShare;

  const WinPoints({
    required this.ronPayment,
    required this.tsumoDoubleShare,
    required this.tsumoSingleShare,
  });

  @override
  String toString() =>
      'WinPoints(ron: $ronPayment, tsumo: $tsumoDoubleShare/$tsumoSingleShare)';

  @override
  bool operator ==(Object other) =>
      other is WinPoints &&
      other.ronPayment == ronPayment &&
      other.tsumoDoubleShare == tsumoDoubleShare &&
      other.tsumoSingleShare == tsumoSingleShare;

  @override
  int get hashCode => Object.hash(ronPayment, tsumoDoubleShare, tsumoSingleShare);
}

typedef _LowHanRow = ({
  int dealerRon,
  int dealerTsumoDouble,
  int nonDealerRon,
  int nonDealerTsumoDouble,
  int nonDealerTsumoSingle,
});

/// STEP5's fixed 1〜3翻 point table, transcribed verbatim — deliberately
/// independent of fu.
const Map<int, _LowHanRow> _fixedLowHanTable = {
  1: (
    dealerRon: 2000,
    dealerTsumoDouble: 1000,
    nonDealerRon: 1000,
    nonDealerTsumoDouble: 1000,
    nonDealerTsumoSingle: 1000,
  ),
  2: (
    dealerRon: 4000,
    dealerTsumoDouble: 2000,
    nonDealerRon: 2000,
    nonDealerTsumoDouble: 1000,
    nonDealerTsumoSingle: 1000,
  ),
  3: (
    dealerRon: 6000,
    dealerTsumoDouble: 3000,
    nonDealerRon: 4000,
    nonDealerTsumoDouble: 3000,
    nonDealerTsumoSingle: 1000,
  ),
};

int _ceilTo1000(int points) => ((points + 999) ~/ 1000) * 1000;

/// Base points (before the ron/tsumo multiplier) for [han]/[fu] at 4+ han,
/// applying the standard mangan-and-above tier caps reused from 4-player
/// mahjong (STEP5「4人麻雀と同一の...点数テーブルを流用」).
int _baseFor(int han, int fu) {
  if (han >= 13) return 8000; // 役満
  if (han >= 11) return 6000; // 三倍満
  if (han >= 8) return 4000; // 倍満
  if (han >= 6) return 3000; // 跳満
  if (han >= 5) return 2000; // 満貫
  final raw = fu * (1 << (2 + han));
  return raw > 2000 ? 2000 : raw; // kiriage-mangan cap
}

WinPoints _pointsFromBase(int base, {required bool winnerIsDealer}) {
  if (winnerIsDealer) {
    final doubleShare = _ceilTo1000(base * 2);
    return WinPoints(
      ronPayment: _ceilTo1000(base * 6),
      tsumoDoubleShare: doubleShare,
      tsumoSingleShare: doubleShare, // unused: winner is dealer, no single-share opponent.
    );
  }
  return WinPoints(
    ronPayment: _ceilTo1000(base * 4),
    tsumoDoubleShare: _ceilTo1000(base * 2),
    tsumoSingleShare: _ceilTo1000(base),
  );
}

WinPoints _pointsForHanFu(int han, int fu, {required bool winnerIsDealer}) {
  if (han <= 3) {
    final row = _fixedLowHanTable[han]!;
    return winnerIsDealer
        ? WinPoints(
            ronPayment: row.dealerRon,
            tsumoDoubleShare: row.dealerTsumoDouble,
            tsumoSingleShare: row.dealerTsumoDouble,
          )
        : WinPoints(
            ronPayment: row.nonDealerRon,
            tsumoDoubleShare: row.nonDealerTsumoDouble,
            tsumoSingleShare: row.nonDealerTsumoSingle,
          );
  }
  return _pointsFromBase(_baseFor(han, fu), winnerIsDealer: winnerIsDealer);
}

/// Points for a win made up entirely of [yaku] (STEP5 closed-form yaku
/// only — see file doc comment). Throws [ArgumentError] if [yaku] isn't one
/// of the combinations this ruleset can actually complete on
/// (`detectClosedFormYaku`'s own output is always valid input here).
WinPoints calculateClosedFormWinPoints({
  required List<ClosedFormYaku> yaku,
  required bool winnerIsDealer,
}) {
  if (yaku.contains(ClosedFormYaku.kokushiMusou)) {
    return _pointsFromBase(8000, winnerIsDealer: winnerIsDealer);
  }

  final han = switch (yaku) {
    [ClosedFormYaku.chiitoitsu] => 2,
    [ClosedFormYaku.chiitoitsuYonmai] => 4,
    [ClosedFormYaku.chiitoitsuHachimai] => 6,
    _ => throw ArgumentError.value(
        yaku,
        'yaku',
        'not a scorable closed-form yaku combination',
      ),
  };

  return _pointsForHanFu(han, 25, winnerIsDealer: winnerIsDealer);
}

/// How a hand was completed — affects the menzen-ron fu bonus and the tsumo
/// fu bonus (STEP5「点数計算」reuses the standard fu table).
enum WinMethod { ron, tsumo }

/// Fu for [decomposition], excluding wait-shape fu (see file doc comment).
/// Rounds up to the nearest 10, matching standard fu-calculation practice.
int calculateStandardFu({
  required StandardDecomposition decomposition,
  required bool isMenzen,
  required WinMethod method,
}) {
  var fu = 20;
  if (isMenzen && method == WinMethod.ron) fu += 10;
  if (method == WinMethod.tsumo) fu += 2;

  for (final group in decomposition.melds.whereType<SetGroup>()) {
    final honorOrTerminal = isHonorKind(group.kind) || isTerminalKind(group.kind);
    final closedTripletFu = honorOrTerminal ? 8 : 4;
    final groupFu = group.tileCount == 4 ? closedTripletFu * 4 : closedTripletFu;
    fu += group.isOpen ? groupFu ~/ 2 : groupFu;
  }

  if (decomposition.pair.kind is Dragon) fu += 2;

  return ((fu + 9) ~/ 10) * 10;
}

/// Points for [hand] as a standard (4 melds + pair) win. Throws
/// [ArgumentError] if it doesn't complete any detectable standard yaku
/// (including the case where it only completes as 国士無双/七対子 — use
/// [calculateClosedFormWinPoints] for those, or [calculateWinPoints] to
/// try both automatically).
///
/// Simultaneous 役満 are assumed to stack (each multiplies the 8000 base),
/// matching common practice — STEP5 doesn't say either way.
WinPoints calculateStandardWinPoints({
  required Hand hand,
  required bool winnerIsDealer,
  required WinMethod method,
}) {
  final result = selectBestStandardHand(hand);
  if (result == null || result.yaku.isEmpty) {
    throw ArgumentError.value(hand, 'hand', 'does not complete any detectable standard yaku');
  }

  final isYakuman = result.yaku.any((y) => hanValueOf(y, isMenzen: hand.isMenzen) >= 13);
  if (isYakuman) {
    return _pointsFromBase(8000 * result.yaku.length, winnerIsDealer: winnerIsDealer);
  }

  final han = result.yaku.fold(0, (sum, y) => sum + hanValueOf(y, isMenzen: hand.isMenzen));
  final fu = calculateStandardFu(
    decomposition: result.decomposition,
    isMenzen: hand.isMenzen,
    method: method,
  );
  return _pointsForHanFu(han, fu, winnerIsDealer: winnerIsDealer);
}

/// Points for [hand], trying 国士無双/七対子 first and falling back to a
/// standard-hand decomposition. Throws [ArgumentError] if neither applies.
WinPoints calculateWinPoints({
  required Hand hand,
  required bool winnerIsDealer,
  required WinMethod method,
}) {
  final closedForm = detectClosedFormYaku(hand);
  if (closedForm.isNotEmpty) {
    return calculateClosedFormWinPoints(yaku: closedForm, winnerIsDealer: winnerIsDealer);
  }
  return calculateStandardWinPoints(hand: hand, winnerIsDealer: winnerIsDealer, method: method);
}
