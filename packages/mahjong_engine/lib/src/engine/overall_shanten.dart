/// Combined shanten across every hand shape this ruleset recognizes
/// (STEP10 実装).
library;

import '../core/hand.dart';
import 'shanten.dart';
import 'standard_shanten.dart';

/// The best (lowest) shanten [hand] can reach reading it as 国士無双,
/// 七対子, or a standard (4 melds + pair) hand. Each sub-shanten already
/// returns a worst-case value when its own shape's constraints aren't met
/// (e.g. any meld rules out kokushi/chiitoitsu), so no extra guarding is
/// needed here.
int overallShanten(Hand hand) {
  final values = [kokushiShanten(hand), chiitoitsuShanten(hand), standardShanten(hand)];
  return values.reduce((a, b) => a < b ? a : b);
}
