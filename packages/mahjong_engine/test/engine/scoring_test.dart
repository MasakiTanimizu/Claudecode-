import 'package:mahjong_engine/mahjong_engine.dart';
import 'package:test/test.dart';

void main() {
  group('calculateClosedFormWinPoints — 七対子 (2翻, fixed table)', () {
    test('dealer', () {
      final points = calculateClosedFormWinPoints(
        yaku: const [ClosedFormYaku.chiitoitsu],
        winnerIsDealer: true,
      );
      expect(
        points,
        const WinPoints(ronPayment: 4000, tsumoDoubleShare: 2000, tsumoSingleShare: 2000),
      );
    });

    test('non-dealer', () {
      final points = calculateClosedFormWinPoints(
        yaku: const [ClosedFormYaku.chiitoitsu],
        winnerIsDealer: false,
      );
      expect(
        points,
        const WinPoints(ronPayment: 2000, tsumoDoubleShare: 1000, tsumoSingleShare: 1000),
      );
    });
  });

  group('calculateClosedFormWinPoints — 七対子4枚使い (4翻, formula)', () {
    test('dealer', () {
      // base = 25fu * 2^(2+4) = 1600 (no mangan cap).
      final points = calculateClosedFormWinPoints(
        yaku: const [ClosedFormYaku.chiitoitsuYonmai],
        winnerIsDealer: true,
      );
      expect(
        points,
        const WinPoints(
          ronPayment: 10000, // ceil(1600*6=9600, 1000)
          tsumoDoubleShare: 4000, // ceil(1600*2=3200, 1000)
          tsumoSingleShare: 4000,
        ),
      );
    });

    test('non-dealer', () {
      final points = calculateClosedFormWinPoints(
        yaku: const [ClosedFormYaku.chiitoitsuYonmai],
        winnerIsDealer: false,
      );
      expect(
        points,
        const WinPoints(
          ronPayment: 7000, // ceil(1600*4=6400, 1000)
          tsumoDoubleShare: 4000, // ceil(1600*2=3200, 1000): dealer opponent
          tsumoSingleShare: 2000, // ceil(1600, 1000): other non-dealer
        ),
      );
    });
  });

  group('calculateClosedFormWinPoints — 七対子8枚使い (6翻, 跳満 tier)', () {
    test('dealer', () {
      // han >= 6 -> haneman tier, base fixed at 3000 regardless of fu.
      final points = calculateClosedFormWinPoints(
        yaku: const [ClosedFormYaku.chiitoitsuHachimai],
        winnerIsDealer: true,
      );
      expect(
        points,
        const WinPoints(ronPayment: 18000, tsumoDoubleShare: 6000, tsumoSingleShare: 6000),
      );
    });

    test('non-dealer', () {
      final points = calculateClosedFormWinPoints(
        yaku: const [ClosedFormYaku.chiitoitsuHachimai],
        winnerIsDealer: false,
      );
      expect(
        points,
        const WinPoints(ronPayment: 12000, tsumoDoubleShare: 6000, tsumoSingleShare: 3000),
      );
    });
  });

  group('calculateClosedFormWinPoints — 国士無双 (役満)', () {
    test('dealer', () {
      final points = calculateClosedFormWinPoints(
        yaku: const [ClosedFormYaku.kokushiMusou],
        winnerIsDealer: true,
      );
      expect(
        points,
        const WinPoints(ronPayment: 48000, tsumoDoubleShare: 16000, tsumoSingleShare: 16000),
      );
    });

    test('non-dealer', () {
      final points = calculateClosedFormWinPoints(
        yaku: const [ClosedFormYaku.kokushiMusou],
        winnerIsDealer: false,
      );
      expect(
        points,
        const WinPoints(ronPayment: 32000, tsumoDoubleShare: 16000, tsumoSingleShare: 8000),
      );
    });
  });

  test('throws for a yaku combination that cannot actually be scored', () {
    expect(
      () => calculateClosedFormWinPoints(yaku: const [], winnerIsDealer: false),
      throwsArgumentError,
    );
  });
}
