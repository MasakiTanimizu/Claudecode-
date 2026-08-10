/// Danger-tile evaluation (STEP8「他家に危険な気配があるかを判定し、あれば
/// 安全牌（現物・スジ・壁）を優先」実装).
///
/// Scoped to 現物 (genbutsu) and スジ (suji) — the two safety reads that only
/// need one opponent's own discard pile. 壁 (kabe: all 4 copies of a tile
/// visible somewhere) needs visibility across every player's discards *and*
/// melds at once, a wider-scope "table state" reader that's a natural
/// follow-up but not needed for the two most common reads.
library;

import '../core/tile.dart';

/// True if [tile] is 現物 against an opponent who discarded (or otherwise
/// passed on ronning) it — the furiten rule makes that opponent unable to
/// ron it, ever, for the rest of the hand.
bool isGenbutsu(Tile tile, List<Tile> opponentDiscards) =>
    opponentDiscards.any((d) => d.tileKind == tile.tileKind);

/// True if [tile] is スジ-safe against a ryanmen wait, given [opponentDiscards]
/// — i.e. a same-suit tile exactly 3 ranks away has already been discarded.
/// This only rules out a ryanmen wait; it says nothing about kanchan/penchan/
/// tanki/shanpon, so it's a much weaker guarantee than genbutsu.
bool isSuji(Tile tile, List<Tile> opponentDiscards) {
  if (tile is! NumberTile || tile.suit == NumberSuit.man) {
    return false; // man has no shuntsu in this ruleset, so no suji applies.
  }
  bool discardedRank(int rank) {
    if (rank < 1 || rank > 9) return false;
    return opponentDiscards
        .any((d) => d is NumberTile && d.suit == tile.suit && d.number == rank);
  }

  return discardedRank(tile.number - 3) || discardedRank(tile.number + 3);
}

/// A coarse combined safety read: genbutsu (fully safe) or suji (safe
/// against ryanmen only, still risky against other wait shapes).
bool isLikelySafe(Tile tile, List<Tile> opponentDiscards) =>
    isGenbutsu(tile, opponentDiscards) || isSuji(tile, opponentDiscards);
