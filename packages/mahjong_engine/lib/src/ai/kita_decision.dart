/// 北を抜くか手牌に残すかの判断 (STEP8「北・華の抜き/保持」判断, 難易度依存).
///
/// 華牌は判断不要 — 抜く以外の選択肢が無い（STEP5「華牌」, 常に即座に抜く）ので、
/// this module only covers 北. Kept-北 only ever helps 国士無双 (STEP5「北の
/// 扱い改定」— 字一色/四喜和 with 北 substituting for a wind aren't modeled by
/// this engine's shanten yet, see standard_shanten.dart's own scope note), so
/// the intermediate/advanced heuristics below are necessarily kokushi-shaped.
library;

import '../core/hand.dart';
import '../core/tile.dart';
import '../engine/shanten.dart';
import '../engine/standard_yaku.dart' show isHonorKind, isTerminalKind;
import 'difficulty.dart';

bool _isTerminalOrHonorTile(Tile tile) => switch (tile) {
      NumberTile t => isTerminalKind((t.suit, t.number)),
      WindTile t => isHonorKind(t.wind),
      DragonTile t => isHonorKind(t.dragon),
      KitaTile _ => true,
      HanaTile _ => false,
    };

/// Whether to keep a just-drawn 北 in [handAfterDraw] (which already
/// includes it) rather than extract it immediately.
///
/// - 初級: always extracts immediately.
/// - 中級: keeps when the hand already leans heavily toward terminals/honors
///   (STEP8「老頭牌・字牌に偏った配牌では保持を検討」) — a coarse proxy for
///   "kokushi might be realistic," since a precise read needs the same
///   shanten check 上級 does.
/// - 上級: keeps when 国士無双 is still a realistic target (STEP8「国士無双...
///   が現実的な時は積極的に保持」), using the actual kokushi shanten rather
///   than the 中級 proxy.
bool shouldKeepDrawnKita(Hand handAfterDraw, CpuDifficulty difficulty) {
  switch (difficulty) {
    case CpuDifficulty.beginner:
      return false;
    case CpuDifficulty.intermediate:
      final terminalOrHonorCount =
          handAfterDraw.concealedTiles.where(_isTerminalOrHonorTile).length;
      return terminalOrHonorCount * 2 >= handAfterDraw.concealedTiles.length;
    case CpuDifficulty.advanced:
      return kokushiShanten(handAfterDraw) <= 4;
  }
}
