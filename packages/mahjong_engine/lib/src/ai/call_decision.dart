/// Whether the CPU should call ポン/大明槓 on another player's discard
/// (STEP8 CPU意思決定フロー, 鳴き判断) — ロン is unconditional (a win is
/// always taken, no heuristic needed) so this only covers ポン/カン.
library;

import '../core/hand.dart';
import '../engine/overall_shanten.dart';
import 'difficulty.dart';

/// Whether calling is worth it: never for 初級 (鳴かない, keeps them
/// simple/passive), otherwise only when the resulting hand (meld formed,
/// [handAfterCall]) doesn't leave the player worse off than staying
/// concealed — same or better [overallShanten] than [handBeforeCall].
bool shouldCall(Hand handBeforeCall, Hand handAfterCall, CpuDifficulty difficulty) {
  if (difficulty == CpuDifficulty.beginner) return false;
  return overallShanten(handAfterCall) <= overallShanten(handBeforeCall);
}
