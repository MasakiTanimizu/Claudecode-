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
/// Scoped to the closed-form yaku from `yaku.dart` (国士無双 and the 七対子
/// variants), since those are the only yaku detectable so far. Standard-hand
/// scoring (fu from wait/meld composition, multi-yaku stacking) is deferred
/// alongside the standard-hand shanten algorithm.
library;

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

  return _pointsFromBase(_baseFor(han, 25), winnerIsDealer: winnerIsDealer);
}
