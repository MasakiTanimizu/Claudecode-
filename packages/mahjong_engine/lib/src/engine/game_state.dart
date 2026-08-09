/// Turn-by-turn state machine for a single 局 (hand/round) (STEP10 実装).
///
/// Scoped to the core draw → (riichi/tsumo) → discard loop, pon/daiminkan/
/// ron on another player's discard, ankan/shouminkan on the current
/// player's own turn, and exhaustive draw (流局). This ruleset doesn't use
/// チー at all (docs/design/05「鳴き・後付け」).
///
/// Every kan (暗槓・大明槓・加槓) reveals the next kan-dora indicator and then
/// draws a replacement tile — mechanically identical to a normal draw since
/// there's no separate 嶺上 pool under the 崖 rule (STEP5「山と王牌」). If the
/// live wall can't cover both, the round ends as an exhaustive draw right
/// there. 槍槓 (ron on a shouminkan's added tile, before it's absorbed) is
/// not exposed as a window here — it's one of the context-dependent yaku
/// already out of scope for `standard_yaku.dart`. A riichi'd hand can
/// never ankan/shouminkan in this implementation — real rules allow ankan
/// after riichi only when it provably doesn't change the wait, which needs
/// machinery this slice doesn't have, so the conservative default is "no."
///
/// Callers are responsible for call priority: this class exposes
/// [canDeclareRon]/[canDeclarePon]/[canDeclareDaiminkan] as independent
/// per-player queries and does not arbitrate between them — real mahjong
/// gives ron priority over pon/kan on the same discard, so check every
/// player's ron eligibility first.
///
/// Every draw (a normal turn draw or a kan replacement) transparently
/// resolves 華牌 and 北 before the caller sees it (STEP5「抜きドラ体系」):
/// a drawn hana tile is always immediately nuku'd (revealed into
/// [nukiTiles] and replaced) with no choice offered, while a drawn kita
/// pauses the state machine at [TurnPhase.awaitingKitaDecision] for the
/// caller to resolve via [nukiKita] or [keepDrawnKita] — except for a
/// player who has already declared riichi, whose locked hand has no route
/// to keep an extra tile, so their kita is always auto-nuku'd like hana.
/// A kita that's kept in hand can never be discarded ([discard] and
/// [declareRiichiAndDiscard] both reject it), matching STEP5's "北は誰の
/// 手からも捨てられない". Neither hana nor kita nuki reveals a dora
/// indicator — only 槓 does that.
///
/// [GameState.deal] resolves hana/kita dealt straight into a starting hand
/// (haipai) before the round's first real turn: every hana is auto-nuku'd
/// exactly like a drawn one, but every kita gets the same [nukiKita]/
/// [keepDrawnKita] choice a drawn one does — dealt-in tiles aren't
/// special-cased into a forced outcome. Since haipai can hand multiple
/// players a kita at once, this walks the table once starting from
/// [dealerIndex], pausing at [TurnPhase.awaitingKitaDecision] for
/// whichever player has one, same as mid-round — see
/// [_advanceHaipaiKitaResolution].
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

enum TurnPhase { awaitingDraw, awaitingDiscard, awaitingKitaDecision, roundOver }

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

  /// Every hana tile and every nuku'd kita tile, indexed by the player who
  /// nuku'd it — public information, revealed the instant it happens
  /// (STEP5「抜きドラ体系」: "即座に公開・補充"). A kita a player chose to
  /// keep in hand instead does *not* appear here.
  final List<List<Tile>> nukiTiles;

  final int dealerIndex;
  final Set<int> riichiDeclared = {};

  int currentPlayerIndex;
  TurnPhase phase;
  RoundResult? result;
  Tile? _drawnTile;

  /// The kita tile just drawn, awaiting [nukiKita] or [keepDrawnKita] —
  /// only non-null while [phase] is [TurnPhase.awaitingKitaDecision].
  Tile? _pendingKitaTile;

  /// True while walking the table for haipai kita decisions, right after
  /// [GameState.deal] — changes what [nukiKita]/[keepDrawnKita] do next
  /// (see [_advanceHaipaiKitaResolution]) versus mid-round.
  bool _resolvingHaipaiKita = false;

  /// How many of each player's kita tiles — already sitting in their hand,
  /// whether dealt straight into their haipai or drawn as a nuku'd haipai
  /// kita's own replacement — are still awaiting a decision. Only non-null
  /// while [_resolvingHaipaiKita] is true.
  ///
  /// [_advanceHaipaiKitaResolution] needs this because a kita a player
  /// chose to *keep* goes right back into that same hand — indistinguishable
  /// from a still-undecided one by looking at the hand alone, so scanning
  /// hand contents for "any kita" would immediately re-offer the one that
  /// was just kept, forever. This count is what actually tracks "still
  /// needs deciding," independent of how many kita happen to be sitting in
  /// the hand at any given moment.
  List<int>? _pendingHaipaiKitaCount;

  GameState({required this.hands, required this.wall, required this.dealerIndex})
      : discardPiles = List.generate(hands.length, (_) => <Tile>[]),
        nukiTiles = List.generate(hands.length, (_) => <Tile>[]),
        currentPlayerIndex = dealerIndex,
        phase = TurnPhase.awaitingDraw;

  /// Deals a fresh hand from [fullTileSet] and wraps it in a ready-to-play
  /// [GameState] (STEP5「山と王牌」via `dealHands`), then immediately
  /// resolves any hana/kita dealt straight into a starting hand (haipai) —
  /// see [_resolveHaipaiNukiTiles].
  factory GameState.deal({
    required List<Tile> fullTileSet,
    required int playerCount,
    required Random random,
    required int dealerIndex,
  }) {
    final dealt = dealHands(fullTileSet, playerCount: playerCount, random: random);
    final state = GameState(
      hands: [for (final h in dealt.hands) Hand(concealedTiles: h)],
      wall: dealt.wall,
      dealerIndex: dealerIndex,
    );
    state._resolveHaipaiNukiTiles();
    return state;
  }

  /// Auto-nuku's every hana dealt straight into a starting hand, replacing
  /// each from the wall (kita is deliberately left alone here — see
  /// [_advanceHaipaiKitaResolution], which is what this hands off to).
  void _resolveHaipaiNukiTiles() {
    for (var player = 0; player < hands.length; player++) {
      _replaceHanaInHand(player);
      if (phase == TurnPhase.roundOver) return; // wall ran out mid-replacement.
    }
    _pendingHaipaiKitaCount = [
      for (final hand in hands) hand.concealedTiles.whereType<KitaTile>().length,
    ];
    _resolvingHaipaiKita = true;
    currentPlayerIndex = dealerIndex;
    _advanceHaipaiKitaResolution();
  }

  /// Strips every hana tile out of [player]'s hand and replaces each from
  /// the wall, chaining past any further hana the replacement draws turn
  /// up. Ends the round as an exhaustive draw if the wall can't cover it.
  void _replaceHanaInHand(int player) {
    final targetSize = hands[player].concealedTiles.length;
    final keep = <Tile>[];
    for (final tile in hands[player].concealedTiles) {
      if (tile is HanaTile) {
        nukiTiles[player].add(tile);
      } else {
        keep.add(tile);
      }
    }
    hands[player] = Hand(concealedTiles: keep, melds: hands[player].melds);

    while (hands[player].concealedTiles.length < targetSize) {
      _drawReplacementSkippingHana(player);
      if (phase == TurnPhase.roundOver) return;
    }
  }

  /// Draws exactly one replacement tile into [player]'s hand, silently
  /// chaining past any hana (auto-nuku'd, no choice) until a non-hana tile
  /// comes up. A kita drawn this way is left in the hand as an ordinary
  /// tile — it's the caller's job to notice it (both
  /// [_advanceHaipaiKitaResolution] and [_resolveNextDraw] do, each in
  /// their own context). Ends the round as an exhaustive draw if the wall
  /// runs out mid-chain.
  void _drawReplacementSkippingHana(int player) {
    while (true) {
      if (wall.isExhausted) {
        phase = TurnPhase.roundOver;
        result = const RoundResult(reason: RoundOverReason.exhaustiveDraw);
        return;
      }
      final tile = wall.draw();
      if (tile is HanaTile) {
        nukiTiles[player].add(tile);
        continue;
      }
      hands[player] = Hand(
        concealedTiles: [...hands[player].concealedTiles, tile],
        melds: hands[player].melds,
      );
      return;
    }
  }

  /// Finds the next player, starting from [currentPlayerIndex] and
  /// wrapping around the table, who still has a kita awaiting a decision
  /// per [_pendingHaipaiKitaCount] — pulls one out of their hand and
  /// pauses at [TurnPhase.awaitingKitaDecision] for it, same as a
  /// mid-round draw would. Once every player's count reaches zero, hands
  /// off to the real first turn ([TurnPhase.awaitingDraw] for
  /// [dealerIndex]).
  void _advanceHaipaiKitaResolution() {
    final pending = _pendingHaipaiKitaCount!;
    for (var i = 0; i < hands.length; i++) {
      final player = (currentPlayerIndex + i) % hands.length;
      if (pending[player] <= 0) continue;
      pending[player]--;
      final concealed = List<Tile>.of(hands[player].concealedTiles);
      concealed.removeAt(concealed.indexWhere((t) => t is KitaTile));
      hands[player] = Hand(concealedTiles: concealed, melds: hands[player].melds);
      currentPlayerIndex = player;
      _pendingKitaTile = const KitaTile();
      phase = TurnPhase.awaitingKitaDecision;
      return;
    }
    _pendingHaipaiKitaCount = null;
    _resolvingHaipaiKita = false;
    currentPlayerIndex = dealerIndex;
    phase = TurnPhase.awaitingDraw;
  }

  bool get isOver => phase == TurnPhase.roundOver;

  Hand get currentHand => hands[currentPlayerIndex];

  void _requirePhase(TurnPhase expected) {
    if (phase != expected) {
      throw StateError('expected phase $expected but was $phase');
    }
  }

  /// The current player draws the next tile, or ends the round as an
  /// exhaustive draw (流局) if the wall has run out (STEP5「崖」). May leave
  /// [phase] at [TurnPhase.awaitingKitaDecision] instead of
  /// [TurnPhase.awaitingDiscard] — see [_resolveNextDraw].
  void drawForCurrentPlayer() {
    _requirePhase(TurnPhase.awaitingDraw);
    _resolveNextDraw();
  }

  /// Draws tiles for [currentPlayerIndex] one at a time, transparently
  /// nuku'ing every hana tile and (unless the player is riichi'd) pausing
  /// on the first kita tile — see the class doc for the full rule. Ends
  /// the round as an exhaustive draw if the wall runs out mid-loop.
  void _resolveNextDraw() {
    while (true) {
      if (wall.isExhausted) {
        phase = TurnPhase.roundOver;
        result = const RoundResult(reason: RoundOverReason.exhaustiveDraw);
        return;
      }
      final tile = wall.draw();
      if (tile is HanaTile) {
        nukiTiles[currentPlayerIndex].add(tile);
        continue;
      }
      if (tile is KitaTile && !riichiDeclared.contains(currentPlayerIndex)) {
        _pendingKitaTile = tile;
        phase = TurnPhase.awaitingKitaDecision;
        return;
      }
      if (tile is KitaTile) {
        // Riichi'd hand is locked — no route to keep an extra tile.
        nukiTiles[currentPlayerIndex].add(tile);
        continue;
      }
      _drawnTile = tile;
      hands[currentPlayerIndex] = Hand(
        concealedTiles: [...currentHand.concealedTiles, tile],
        melds: currentHand.melds,
      );
      phase = TurnPhase.awaitingDiscard;
      return;
    }
  }

  /// Whether the current player has a kita tile awaiting [nukiKita] or
  /// [keepDrawnKita].
  bool get hasPendingKitaDecision => phase == TurnPhase.awaitingKitaDecision;

  /// The kita tile awaiting a decision — only non-null while
  /// [hasPendingKitaDecision] is true.
  Tile? get pendingKitaTile => _pendingKitaTile;

  /// The current player reveals (nuku's) the kita tile they just drew (or,
  /// during haipai resolution, were dealt), then draws again (STEP5「北」:
  /// "抜く（即座に公開・補充）") — or, if this is haipai, moves on to the
  /// next player's own kita, if any. If that replacement draw is itself a
  /// kita, it joins the same player's pending count rather than being
  /// silently left undecided in their hand.
  void nukiKita() {
    _requirePhase(TurnPhase.awaitingKitaDecision);
    final player = currentPlayerIndex;
    nukiTiles[player].add(_pendingKitaTile!);
    _pendingKitaTile = null;
    if (_resolvingHaipaiKita) {
      _drawReplacementSkippingHana(player);
      if (phase == TurnPhase.roundOver) return;
      if (hands[player].concealedTiles.last is KitaTile) {
        _pendingHaipaiKitaCount![player]++;
      }
      _advanceHaipaiKitaResolution();
    } else {
      _resolveNextDraw();
    }
  }

  /// The current player keeps the kita tile they just drew (or were dealt)
  /// in their concealed hand instead of nuku'ing it. From here it can
  /// never be discarded (STEP5「北」) — it stays until the round ends.
  void keepDrawnKita() {
    _requirePhase(TurnPhase.awaitingKitaDecision);
    final player = currentPlayerIndex;
    final tile = _pendingKitaTile!;
    _pendingKitaTile = null;
    hands[player] = Hand(
      concealedTiles: [...hands[player].concealedTiles, tile],
      melds: hands[player].melds,
    );
    if (_resolvingHaipaiKita) {
      _advanceHaipaiKitaResolution();
    } else {
      _drawnTile = tile;
      phase = TurnPhase.awaitingDiscard;
    }
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
  /// locked (STEP5 default riichi behavior). A kita kept in hand can never
  /// be discarded (STEP5「北」), and neither can a hana — though in
  /// practice a hana should never be sitting in a hand to begin with, since
  /// every hand-entry point ([_resolveNextDraw], [_resolveHaipaiNukiTiles])
  /// already auto-nuku's it; this is a last-resort guard, not the primary
  /// defense.
  void discard(Tile tile) {
    _requirePhase(TurnPhase.awaitingDiscard);
    if (tile is KitaTile) {
      throw StateError('北 can never be discarded — nuku it or keep it until the round ends');
    }
    if (tile is HanaTile) {
      throw StateError('華牌 can never be discarded');
    }
    if (riichiDeclared.contains(currentPlayerIndex) && tile != _drawnTile) {
      throw StateError('a riichi hand can only discard the tile just drawn');
    }
    _finishDiscard(tile);
  }

  /// The current player declares riichi and discards [tile] in the same
  /// action. Requires a menzen hand that is tenpai *after* the discard.
  void declareRiichiAndDiscard(Tile tile) {
    _requirePhase(TurnPhase.awaitingDiscard);
    if (tile is KitaTile) {
      throw StateError('北 can never be discarded — nuku it or keep it until the round ends');
    }
    if (tile is HanaTile) {
      throw StateError('華牌 can never be discarded');
    }
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
  /// a discard and before the next player has drawn. A caller building a
  /// reaction UI (e.g. "プレイヤーNの捨てた牌をポンできます") can use this
  /// together with [discardPiles] to name the discard a [canDeclarePon]/
  /// [canDeclareRon]/[canDeclareDaiminkan] query is actually about.
  int get lastDiscarderIndex => (currentPlayerIndex - 1 + hands.length) % hands.length;

  /// Whether [playerIndex] could declare ron on the tile just discarded.
  /// Only meaningful right after a discard (phase is [TurnPhase.awaitingDraw]
  /// for the *next* player) and before that next player draws.
  bool canDeclareRon(int playerIndex) {
    if (phase != TurnPhase.awaitingDraw) return false;
    final lastDiscarder = lastDiscarderIndex;
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
    final lastDiscarder = lastDiscarderIndex;
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
    final lastDiscarder = lastDiscarderIndex;
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
    final calledTile = discardPiles[lastDiscarderIndex].last;
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

  /// Reveals the next kan-dora indicator and draws a replacement tile for
  /// the current player (STEP5「崖」: mechanically identical to a normal
  /// draw, so it resolves hana/kita the same way as [_resolveNextDraw]).
  /// Ends the round as an exhaustive draw if the live wall can't cover both
  /// the reveal and the draw.
  void _drawReplacementAfterKan() {
    if (wall.remainingLiveCount < 2) {
      phase = TurnPhase.roundOver;
      result = const RoundResult(reason: RoundOverReason.exhaustiveDraw);
      return;
    }
    wall.revealNextDoraIndicator();
    _resolveNextDraw();
  }

  /// Whether the current player can declare ankan on 4 concealed copies of
  /// [tile]'s kind. Only meaningful right after their own draw.
  bool canDeclareAnkan(Tile tile) {
    if (phase != TurnPhase.awaitingDiscard) return false;
    if (riichiDeclared.contains(currentPlayerIndex)) return false;
    final count = currentHand.concealedTiles.where((t) => t.tileKind == tile.tileKind).length;
    return count >= 4;
  }

  /// The current player declares ankan on 4 concealed copies of [tile]'s
  /// kind, then reveals a kan-dora indicator and draws a replacement.
  void declareAnkan(Tile tile) {
    if (!canDeclareAnkan(tile)) {
      throw StateError('cannot ankan $tile right now');
    }
    final concealed = List<Tile>.of(currentHand.concealedTiles);
    final claimed = <Tile>[];
    for (var i = concealed.length - 1; i >= 0 && claimed.length < 4; i--) {
      if (concealed[i].tileKind == tile.tileKind) {
        claimed.add(concealed.removeAt(i));
      }
    }
    final meld = Meld.kantsu(claimed, source: CallSource.ankan);
    hands[currentPlayerIndex] = Hand(
      concealedTiles: concealed,
      melds: [...currentHand.melds, meld],
    );
    _drawReplacementAfterKan();
  }

  /// Whether [playerIndex] holds 3 matching concealed tiles and could
  /// daiminkan the tile just discarded. Same reaction window as
  /// [canDeclarePon].
  bool canDeclareDaiminkan(int playerIndex) {
    if (phase != TurnPhase.awaitingDraw) return false;
    if (riichiDeclared.contains(playerIndex)) return false;
    final lastDiscarder = lastDiscarderIndex;
    if (playerIndex == lastDiscarder) return false;
    final pile = discardPiles[lastDiscarder];
    if (pile.isEmpty) return false;

    final tileKind = pile.last.tileKind;
    final matching = hands[playerIndex].concealedTiles.where((t) => t.tileKind == tileKind).length;
    return matching >= 3;
  }

  /// [playerIndex] declares daiminkan on the tile just discarded, forming
  /// an open kantsu from it plus three matching concealed tiles. Turn order
  /// jumps straight to [playerIndex], who then gets a kan-dora reveal and a
  /// replacement draw before their discard.
  void declareDaiminkan(int playerIndex) {
    if (!canDeclareDaiminkan(playerIndex)) {
      throw StateError('player $playerIndex cannot daiminkan right now');
    }
    final calledTile = discardPiles[lastDiscarderIndex].last;
    final hand = hands[playerIndex];
    final concealed = List<Tile>.of(hand.concealedTiles);
    final claimed = <Tile>[];
    for (var i = concealed.length - 1; i >= 0 && claimed.length < 3; i--) {
      if (concealed[i].tileKind == calledTile.tileKind) {
        claimed.add(concealed.removeAt(i));
      }
    }
    final meld = Meld.kantsu([...claimed, calledTile], source: CallSource.daiminkan);

    hands[playerIndex] = Hand(concealedTiles: concealed, melds: [...hand.melds, meld]);
    currentPlayerIndex = playerIndex;
    _drawReplacementAfterKan();
  }

  /// Whether the current player can upgrade an existing open pon of
  /// [tile]'s kind into a kan using a matching concealed tile.
  bool canDeclareShouminkan(Tile tile) {
    if (phase != TurnPhase.awaitingDiscard) return false;
    if (riichiDeclared.contains(currentPlayerIndex)) return false;
    final hasMatchingConcealed =
        currentHand.concealedTiles.any((t) => t.tileKind == tile.tileKind);
    if (!hasMatchingConcealed) return false;
    return currentHand.melds.any(
      (m) =>
          m.kind == MeldKind.kotsu &&
          m.source == CallSource.pon &&
          m.tiles.first.tileKind == tile.tileKind,
    );
  }

  /// The current player upgrades their existing pon of [tile]'s kind into a
  /// kan, then reveals a kan-dora indicator and draws a replacement.
  void declareShouminkan(Tile tile) {
    if (!canDeclareShouminkan(tile)) {
      throw StateError('cannot shouminkan $tile right now');
    }
    final hand = currentHand;
    final existingPon = hand.melds.firstWhere(
      (m) =>
          m.kind == MeldKind.kotsu &&
          m.source == CallSource.pon &&
          m.tiles.first.tileKind == tile.tileKind,
    );
    final concealed = List<Tile>.of(hand.concealedTiles);
    final addedTile = concealed.removeAt(concealed.indexWhere((t) => t.tileKind == tile.tileKind));
    final newMeld = Meld.kantsu([...existingPon.tiles, addedTile], source: CallSource.shouminkan);
    final otherMelds = hand.melds.where((m) => m != existingPon).toList();

    hands[currentPlayerIndex] = Hand(concealedTiles: concealed, melds: [...otherMelds, newMeld]);
    _drawReplacementAfterKan();
  }
}
