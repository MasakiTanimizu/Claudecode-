/// Turn-by-turn state machine for a single 局 (hand/round) (STEP10 実装).
///
/// Scoped to the core draw → (riichi/tsumo) → discard loop, pon/ron on
/// another player's discard, and exhaustive draw (流局). Kan (暗槓・大明槓・
/// 加槓 — this ruleset doesn't use チー, docs/design/05「鳴き・後付け」) is NOT
/// handled here yet: it needs a replacement draw and an extra dora reveal
/// (STEP5「崖」/「ドラ表示」), which is a bigger addition than pon's plain
/// meld-and-discard. Deferred to its own slice.
///
/// Callers are responsible for call priority: this class exposes
/// [canDeclareRon]/[canDeclarePon] as independent per-player queries and
/// does not arbitrate between them — real mahjong gives ron priority over
/// pon on the same discard, so check every player's ron eligibility before
/// acting on a pon.
///
/// A hand is judged winnable using the same yaku detectors as the rest of
/// `engine/` (`yaku.dart`, `standard_yaku.dart`), with one addition: a
/// player who has declared riichi is always treated as having a yaku (立直
/// itself), since riichi-as-a-yaku isn't modeled by the shape-only
/// detectors — see their own scope notes.
library;

import 'dart:math';

import '../core/hand.dart';
import '../core/meld.dart';
import '../core/tile.dart';
import '../core/wall.dart';
import 'shanten.dart';
import 'standard_shanten.dart';
import 'standard_yaku.dart';
import 'yaku.dart';

enum TurnPhase { awaitingDraw, awaitingDiscard, roundOver }

enum RoundOverReason { tsumo, ron, exhaustiveDraw }

class RoundResult {
  final RoundOverReason reason;
  final int? winnerIndex;
  final int? dealtInIndex; // only set for ron.
  const RoundResult({required this.reason, this.winnerIndex, this.dealtInIndex});

  @override
  String toString() => 'RoundResult($reason, winner: $winnerIndex, dealtIn: $dealtInIndex)';
}

bool _isCompleteHand(Hand hand) =>
    kokushiShanten(hand) == -1 || chiitoitsuShanten(hand) == -1 || standardShanten(hand) == -1;

bool _hasShapeYaku(Hand hand) =>
    detectClosedFormYaku(hand).isNotEmpty || detectStandardYaku(hand).isNotEmpty;

class GameState {
  final List<Hand> hands;
  final Wall wall;
  final List<List<Tile>> discardPiles;
  final int dealerIndex;
  final Set<int> riichiDeclared = {};

  int currentPlayerIndex;
  TurnPhase phase;
  RoundResult? result;
  Tile? _drawnTile;

  GameState({required this.hands, required this.wall, required this.dealerIndex})
      : discardPiles = List.generate(hands.length, (_) => <Tile>[]),
        currentPlayerIndex = dealerIndex,
        phase = TurnPhase.awaitingDraw;

  /// Deals a fresh hand from [fullTileSet] and wraps it in a ready-to-play
  /// [GameState] (STEP5「山と王牌」via `dealHands`).
  factory GameState.deal({
    required List<Tile> fullTileSet,
    required int playerCount,
    required Random random,
    required int dealerIndex,
  }) {
    final dealt = dealHands(fullTileSet, playerCount: playerCount, random: random);
    return GameState(
      hands: [for (final h in dealt.hands) Hand(concealedTiles: h)],
      wall: dealt.wall,
      dealerIndex: dealerIndex,
    );
  }

  bool get isOver => phase == TurnPhase.roundOver;

  Hand get currentHand => hands[currentPlayerIndex];

  void _requirePhase(TurnPhase expected) {
    if (phase != expected) {
      throw StateError('expected phase $expected but was $phase');
    }
  }

  /// The current player draws the next tile, or ends the round as an
  /// exhaustive draw (流局) if the wall has run out (STEP5「崖」).
  void drawForCurrentPlayer() {
    _requirePhase(TurnPhase.awaitingDraw);
    if (wall.isExhausted) {
      phase = TurnPhase.roundOver;
      result = const RoundResult(reason: RoundOverReason.exhaustiveDraw);
      return;
    }
    final tile = wall.draw();
    _drawnTile = tile;
    hands[currentPlayerIndex] = Hand(
      concealedTiles: [...currentHand.concealedTiles, tile],
      melds: currentHand.melds,
    );
    phase = TurnPhase.awaitingDiscard;
  }

  bool _canWinWithYaku(int playerIndex, {required bool checkRiichi}) {
    final hand = hands[playerIndex];
    if (!_isCompleteHand(hand)) return false;
    if (_hasShapeYaku(hand)) return true;
    return checkRiichi && riichiDeclared.contains(playerIndex);
  }

  /// Whether the current player (right after drawing) can declare tsumo.
  bool canDeclareTsumo() {
    if (phase != TurnPhase.awaitingDiscard) return false;
    return _canWinWithYaku(currentPlayerIndex, checkRiichi: true);
  }

  /// The current player declares tsumo, ending the round.
  void declareTsumo() {
    _requirePhase(TurnPhase.awaitingDiscard);
    if (!_canWinWithYaku(currentPlayerIndex, checkRiichi: true)) {
      throw StateError('current hand is not a winning hand with a yaku');
    }
    phase = TurnPhase.roundOver;
    result = RoundResult(reason: RoundOverReason.tsumo, winnerIndex: currentPlayerIndex);
  }

  Hand _handAfterDiscard(Tile tile) {
    final tiles = List<Tile>.of(currentHand.concealedTiles);
    if (!tiles.remove(tile)) {
      throw StateError('$tile is not in the current hand');
    }
    return Hand(concealedTiles: tiles, melds: currentHand.melds);
  }

  void _finishDiscard(Tile tile) {
    hands[currentPlayerIndex] = _handAfterDiscard(tile);
    discardPiles[currentPlayerIndex].add(tile);
    _drawnTile = null;
    currentPlayerIndex = (currentPlayerIndex + 1) % hands.length;
    phase = TurnPhase.awaitingDraw;
  }

  /// The current player discards [tile]. If they've already declared
  /// riichi, [tile] must be the one they just drew — a riichi hand stays
  /// locked (STEP5 default riichi behavior).
  void discard(Tile tile) {
    _requirePhase(TurnPhase.awaitingDiscard);
    if (riichiDeclared.contains(currentPlayerIndex) && tile != _drawnTile) {
      throw StateError('a riichi hand can only discard the tile just drawn');
    }
    _finishDiscard(tile);
  }

  /// The current player declares riichi and discards [tile] in the same
  /// action. Requires a menzen hand that is tenpai *after* the discard.
  void declareRiichiAndDiscard(Tile tile) {
    _requirePhase(TurnPhase.awaitingDiscard);
    if (!currentHand.isMenzen) {
      throw StateError('cannot declare riichi with an open hand');
    }
    if (riichiDeclared.contains(currentPlayerIndex)) {
      throw StateError('already riichi');
    }
    final afterDiscard = _handAfterDiscard(tile);
    final isTenpai = kokushiShanten(afterDiscard) == 0 ||
        chiitoitsuShanten(afterDiscard) == 0 ||
        standardShanten(afterDiscard) == 0;
    if (!isTenpai) {
      throw StateError('hand is not tenpai after discarding $tile');
    }
    riichiDeclared.add(currentPlayerIndex);
    _finishDiscard(tile);
  }

  /// The player who made the discard currently open for ron/pon — only
  /// meaningful while [phase] is [TurnPhase.awaitingDraw], i.e. right after
  /// a discard and before the next player has drawn.
  int get _lastDiscarderIndex => (currentPlayerIndex - 1 + hands.length) % hands.length;

  /// Whether [playerIndex] could declare ron on the tile just discarded.
  /// Only meaningful right after a discard (phase is [TurnPhase.awaitingDraw]
  /// for the *next* player) and before that next player draws.
  bool canDeclareRon(int playerIndex) {
    if (phase != TurnPhase.awaitingDraw) return false;
    final lastDiscarder = _lastDiscarderIndex;
    if (playerIndex == lastDiscarder) return false;
    final pile = discardPiles[lastDiscarder];
    if (pile.isEmpty) return false;

    final hypotheticalHand = Hand(
      concealedTiles: [...hands[playerIndex].concealedTiles, pile.last],
      melds: hands[playerIndex].melds,
    );
    if (!_isCompleteHand(hypotheticalHand)) return false;
    if (_hasShapeYaku(hypotheticalHand)) return true;
    return riichiDeclared.contains(playerIndex);
  }

  /// [playerIndex] declares ron on the tile just discarded, ending the
  /// round. Does not remove the tile from the discarder's pile — the win
  /// is recorded via [RoundResult], the pile stays as a historical record.
  void declareRon(int playerIndex) {
    if (!canDeclareRon(playerIndex)) {
      throw StateError('player $playerIndex cannot declare ron right now');
    }
    final lastDiscarder = _lastDiscarderIndex;
    phase = TurnPhase.roundOver;
    result = RoundResult(
      reason: RoundOverReason.ron,
      winnerIndex: playerIndex,
      dealtInIndex: lastDiscarder,
    );
  }

  /// Whether [playerIndex] holds a matching pair and could pon the tile
  /// just discarded. Same reaction window as [canDeclareRon]. A player who
  /// has already declared riichi can never pon — their hand is locked.
  bool canDeclarePon(int playerIndex) {
    if (phase != TurnPhase.awaitingDraw) return false;
    if (riichiDeclared.contains(playerIndex)) return false;
    final lastDiscarder = _lastDiscarderIndex;
    if (playerIndex == lastDiscarder) return false;
    final pile = discardPiles[lastDiscarder];
    if (pile.isEmpty) return false;

    final tileKind = pile.last.tileKind;
    final matching = hands[playerIndex].concealedTiles.where((t) => t.tileKind == tileKind).length;
    return matching >= 2;
  }

  /// [playerIndex] declares pon on the tile just discarded, forming an open
  /// triplet from it plus two matching concealed tiles. Turn order jumps
  /// straight to [playerIndex], who now owes an immediate discard (no
  /// draw) — this method doesn't choose which tile.
  void declarePon(int playerIndex) {
    if (!canDeclarePon(playerIndex)) {
      throw StateError('player $playerIndex cannot pon right now');
    }
    final calledTile = discardPiles[_lastDiscarderIndex].last;
    final hand = hands[playerIndex];
    final concealed = List<Tile>.of(hand.concealedTiles);
    final claimed = <Tile>[];
    for (var i = concealed.length - 1; i >= 0 && claimed.length < 2; i--) {
      if (concealed[i].tileKind == calledTile.tileKind) {
        claimed.add(concealed.removeAt(i));
      }
    }
    final meld = Meld.kotsu([...claimed, calledTile], source: CallSource.pon);

    hands[playerIndex] = Hand(concealedTiles: concealed, melds: [...hand.melds, meld]);
    currentPlayerIndex = playerIndex;
    _drawnTile = null;
    phase = TurnPhase.awaitingDiscard;
  }
}
