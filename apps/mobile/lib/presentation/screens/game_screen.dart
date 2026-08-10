import 'dart:math';

import 'package:flutter/material.dart';
import 'package:mahjong_engine/mahjong_engine.dart';
import 'package:shared_protocol/shared_protocol.dart';

import '../widgets/hand_view.dart';
import '../widgets/mahjong_table_view.dart';
import '../widgets/tile_view.dart';

/// One player's view of a live [GameState] (STEP7「対局画面」), interactive
/// for the viewer's own turn: the viewer's draw happens automatically (no
/// manual "ツモ" button — drawing carries no decision, unlike discarding),
/// then they double-tap a tile to discard, declare tsumo when available,
/// declare riichi ([_toggleRiichiMode] then double-tap a tenpai-preserving
/// tile), declare 暗槓/加槓 when their hand allows it ([_ankan]/
/// [_shouminkan]), or resolve a kita (抜く/キャンセル, i.e. keep it in hand)
/// whenever one comes up — including any dealt straight into their opening
/// hand, which [GameState] offers the exact same choice for as one drawn
/// mid-round. While that decision is pending, the drawn kita is shown
/// appended to "自分の手牌" (it isn't in [GameState]'s hand yet — only
/// [keepDrawnKita] puts it there — but showing it lets the viewer see what
/// they're actually being asked to keep or nuku).
///
/// The other two players are driven locally by the tile-
/// efficiency CPU baseline (`ai/heuristic_discard.dart` and
/// `ai/kita_decision.dart`), both mid-round and for their own haipai kita
/// ([_resolveKitaDecisionsForCpu], also reused from [initState]) — they
/// also riichi themselves whenever their chosen discard would keep them
/// tenpai. Hana tiles never reach here as a decision, haipai included —
/// [GameState] always auto-nuku's them.
///
/// Whenever a discard is one another player could ron, pon, and/or
/// daiminkan, [_resolveReactionsToLastDiscard] arbitrates by real mahjong's
/// call priority ([_reactionPriorityOrder]: ロン beats ポン/カン, and among
/// several eligible players whoever sits closest after the discarder gets
/// first refusal). CPUs act on their own immediately — ロン is always
/// taken, ポン/カン go through `ai/call_decision.dart`'s [shouldCall] — so
/// the game only actually pauses (offering ロン/ポン/カン/キャンセル) when
/// the *viewer* is the one with priority; declining (or having no reaction
/// at all) resumes the normal flow. A CPU's call forces an immediate
/// discard of their own, which can chain into further reactions the same
/// way.
///
/// The result banner shown once the round ends also names the points —
/// [_tryScoreWin] runs the win through `engine/scoring.dart`, except for a
/// riichi-only win (立直 alone, no other yaku), which that module can't
/// score yet; the banner just omits the point figure for that one case
/// rather than guessing.
///
/// A hana tile being auto-nuku'd also shows a brief popup naming who and
/// which tile ([_hanaPopups]/[_trackHana]) — cleared at the start of the
/// next user action rather than on a timer, since a real one would leave a
/// pending Timer at test teardown unless every affected test remembered to
/// flush it. Each seat's own nuki tiles (hana and kita alike) also stay
/// visible as small badges next to their label on [MahjongTableView] for a
/// lasting record, not just the transient popup.
///
/// When [match] is provided, a finished round also offers a "次局へ"
/// button: tapping it feeds the just-finished [GameState] through
/// [MatchState.advance] (updating running scores/dealer/honba) and, unless
/// that was 半荘's last hand, deals and swaps in a fresh [GameState] for
/// the next 局 in place — [_state] is a mutable field for exactly this,
/// not just a `widget.state` passthrough. Once the match itself ends, the
/// board is replaced by a final-scores summary instead. [match] is null
/// for a single-round session (every existing screen/flow that doesn't
/// care about round-to-round continuation) — nothing in this paragraph
/// applies then, and the round-over banner is the final state.
///
/// Still out of scope here: ankan/shouminkan as a reaction to someone
/// else's discard/kan (槍槓) isn't modeled — only ロン/ポン/大明槓 are;
/// exhaustive draws never pay tenpai/noten points (see [MatchState]'s own
/// scope note — honba still accrues correctly, just no point transfer);
/// and there's no wait-tile highlighting or animation for a hana/kita tile
/// itself moving out of the hand (just the popup/badges above) — worth
/// animating once there's a reason to invest in it, not urgent before
/// then.
class GameScreen extends StatefulWidget {
  final GameState state;
  final int viewerIndex;
  final MatchState? match;
  final Map<String, Object?> config;

  const GameScreen({
    required this.state,
    this.viewerIndex = 0,
    this.match,
    this.config = const {},
    super.key,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

// Shared by every CPU decision (kita, and now pon/kan calls too).
const _cpuDifficulty = CpuDifficulty.intermediate;

class _GameScreenState extends State<GameScreen> {
  // A mutable field, not just a `widget.state` passthrough — starting the
  // next 局 (via [_startNextRound]) swaps in a fresh [GameState] here
  // rather than replacing the whole widget.
  late GameState _state;

  // Identifies the one specific discard (by discarder + that discarder's
  // pile length right after it) the viewer has already declined to react
  // to (ron, pon, or kan) — otherwise re-checking after キャンセル would
  // just immediately re-offer the same still-callable discard forever. A
  // pile length only ever grows, so this can never false-match a later
  // discard.
  int? _declinedReactionDiscarderIndex;
  int? _declinedReactionPileLength;

  // Whether the viewer has pressed リーチ and is now picking which tile to
  // riichi-discard — while true, [_discard] declares riichi with the
  // tapped tile instead of a plain discard (and ignores taps on tiles that
  // wouldn't keep the hand tenpai, rather than surprising the player with
  // a plain discard they didn't ask for).
  bool _riichiMode = false;

  // Hana tiles nuku'd as a direct result of the most recent user action
  // (the viewer's own draw/kita/kan, or any CPU turns that action set off),
  // shown as a small popup near "自分の手牌" so it's visible on-screen that
  // it happened (STEP7: hana are auto-nuku'd with no decision, so without
  // this there'd be no visible record besides the seat's nuki-tile badge).
  // Cleared at the start of the next user action rather than on a timer —
  // a timer would leave one pending at test teardown unless every affected
  // test remembered to flush it (see this file's git history for that
  // exact problem with an earlier SnackBar-based version of this).
  List<({int player, HanaTile tile})> _hanaPopups = [];

  /// Runs [action] (an engine call for [player]) and appends any hana
  /// tiles it newly nuku's to [_hanaPopups]. Covers every engine call that
  /// can draw a replacement tile mid-call and so might transparently nuku
  /// a hana along the way: a plain draw, a kita nuku (mid-round or haipai),
  /// and a kan's post-declaration replacement draw.
  void _trackHana(int player, void Function() action) {
    final before = _state.nukiTiles[player].length;
    action();
    for (final tile in _state.nukiTiles[player].skip(before)) {
      if (tile is HanaTile) _hanaPopups.add((player: player, tile: tile));
    }
  }

  @override
  void initState() {
    super.initState();
    _state = widget.state;
    // The one-time, dealer-first haipai kita sweep GameState.deal() already
    // ran and may be paused on any player, viewer included — resolve
    // whichever CPUs come first in it, same as mid-round. Once that sweep
    // is fully done it hands off to TurnPhase.awaitingDraw for the dealer
    // — if the dealer isn't the viewer, _runCpuTurns() has to be the one
    // to actually draw for them; _autoDrawForViewerIfNeeded() only ever
    // fires for the viewer's own turn, so without this the game would
    // freeze right here on mount whenever dealerIndex != viewerIndex
    // (roughly 2 times out of 3) with nothing yet pressed. Can't setState
    // this early (the element isn't mounted yet) — mutate directly, since
    // the very first build() already reads fresh state.
    //
    // [widget.state] could also arrive already sitting on an unresolved
    // discard (phase awaitingDraw right after someone's discard, viewer
    // reaction still open) rather than a fresh deal — same check
    // [_advanceAfterDiscard] always runs before its own [_runCpuTurns]
    // call, needed here too or [_runCpuTurns] would draw straight past the
    // viewer's ロン/ポン/カン window without ever offering it.
    _resolveKitaDecisionsForCpu();
    if (_resolveReactionsToLastDiscard()) return;
    _runCpuTurns();
    _autoDrawForViewerIfNeeded();
  }

  /// Draws for the viewer with no button press needed, the moment it's
  /// their turn and nothing else is pending — a draw carries no decision,
  /// so there's nothing for the viewer to choose before it happens.
  void _autoDrawForViewerIfNeeded() {
    if (!_state.isOver &&
        _state.currentPlayerIndex == widget.viewerIndex &&
        _state.phase == TurnPhase.awaitingDraw) {
      _trackHana(widget.viewerIndex, _state.drawForCurrentPlayer);
    }
  }

  /// The viewer nuku's their own pending kita, then — same as
  /// [initState] — resolves whatever CPU haipai kita the sweep moves on to
  /// next, drives any CPU's normal turn if the sweep just handed off to
  /// one, and draws for the viewer if it lands back on them. Without the
  /// [_runCpuTurns] call specifically, a sweep that finishes by handing
  /// off to a non-viewer dealer's ordinary turn (not another kita) would
  /// leave the game stopped with nothing drawing for that dealer — the
  /// exact same freeze [initState] guards against, just triggered by a tap
  /// instead of on mount. Also checks [_resolveReactionsToLastDiscard]
  /// first, same as [initState], in case the hand-off lands right after a
  /// discard the viewer could still react to.
  void _nukiKita() {
    setState(() {
      _hanaPopups = [];
      _trackHana(_state.currentPlayerIndex, _state.nukiKita);
      _resolveKitaDecisionsForCpu();
      if (_resolveReactionsToLastDiscard()) return;
      _runCpuTurns();
      _autoDrawForViewerIfNeeded();
    });
  }

  /// The keep-in-hand counterpart to [_nukiKita] — see its doc for why
  /// this also has to keep the haipai sweep (and any CPU turn it hands off
  /// to) moving afterward.
  void _keepKita() {
    setState(() {
      _hanaPopups = [];
      _state.keepDrawnKita(); // never itself draws — nothing to _trackHana here.
      _resolveKitaDecisionsForCpu();
      if (_resolveReactionsToLastDiscard()) return;
      _runCpuTurns();
      _autoDrawForViewerIfNeeded();
    });
  }

  void _discard(Tile tile) {
    if (_riichiMode) {
      if (!_state.canDeclareRiichiWith(tile)) return; // only a tenpai-preserving tile is valid.
      setState(() {
        _hanaPopups = [];
        _state.declareRiichiAndDiscard(tile);
        _riichiMode = false;
        _advanceAfterDiscard();
      });
      return;
    }
    setState(() {
      _hanaPopups = [];
      _state.discard(tile);
      _advanceAfterDiscard();
    });
  }

  void _toggleRiichiMode() {
    setState(() => _riichiMode = !_riichiMode);
  }

  void _ankan(Tile tile) {
    setState(() {
      _hanaPopups = [];
      _trackHana(_state.currentPlayerIndex, () => _state.declareAnkan(tile));
      _riichiMode = false; // the hand just changed; any pending riichi pick is stale.
    });
  }

  void _shouminkan(Tile tile) {
    setState(() {
      _hanaPopups = [];
      _trackHana(_state.currentPlayerIndex, () => _state.declareShouminkan(tile));
      _riichiMode = false;
    });
  }

  /// A concealed tile the viewer could ankan right now, if any — the
  /// first tile kind found with 4 concealed copies.
  Tile? _ankanCandidate() {
    final tally = <Object, int>{};
    for (final tile in _state.currentHand.concealedTiles) {
      tally[tile.tileKind] = (tally[tile.tileKind] ?? 0) + 1;
    }
    for (final tile in _state.currentHand.concealedTiles) {
      if (tally[tile.tileKind]! >= 4 && _state.canDeclareAnkan(tile)) return tile;
    }
    return null;
  }

  /// A concealed tile the viewer could use to upgrade an existing pon into
  /// a shouminkan right now, if any.
  Tile? _shouminkanCandidate() {
    for (final tile in _state.currentHand.concealedTiles) {
      if (_state.canDeclareShouminkan(tile)) return tile;
    }
    return null;
  }

  /// Advances the game past a discard that was just made (by the viewer or
  /// a CPU) — unless the viewer has a reaction to make on it (and hasn't
  /// already declined), in which case this pauses right here so the UI can
  /// offer ロン/ポン/カン/キャンセル instead of silently moving on. Any CPU
  /// reactions along the way are resolved automatically first, inside
  /// [_resolveReactionsToLastDiscard].
  void _advanceAfterDiscard() {
    if (_resolveReactionsToLastDiscard()) return;
    _runCpuTurns();
    _autoDrawForViewerIfNeeded();
  }

  bool _viewerDeclinedCurrentReaction() =>
      _declinedReactionDiscarderIndex == _state.lastDiscarderIndex &&
      _declinedReactionPileLength == _state.discardPiles[_state.lastDiscarderIndex].length;

  /// The two non-discarder players, closest-in-turn-order first — real
  /// mahjong's call priority order (STEP8「鳴きの優先順位」): whoever sits
  /// right after the discarder gets first refusal on any given discard.
  List<int> _reactionPriorityOrder() {
    final discarder = _state.lastDiscarderIndex;
    return [for (var offset = 1; offset < _state.hands.length; offset++) (discarder + offset) % _state.hands.length];
  }

  /// After any discard (viewer's or a CPU's), resolves whether either of
  /// the other two players reacts to it: ロン always outranks ポン/カン,
  /// and among multiple eligible players [_reactionPriorityOrder] decides
  /// who gets it. A CPU acts immediately — ロン is always taken, ポン/カン
  /// go through [shouldCall] — while the viewer's own eligibility just
  /// pauses here so ロン/ポン/カン/キャンセル can be offered through the UI
  /// (a キャンセル on any of them counts as declining all three for this
  /// discard, same as [_viewerDeclinedCurrentReaction] already assumes). A
  /// CPU's call forces an immediate discard of their own, which could draw
  /// a fresh reaction in turn — this loops until nobody (viewer included)
  /// has anything left to react to, or the round ends.
  ///
  /// Returns true if the caller should stop here (round over, or the
  /// viewer has something to react to); false once nobody does, meaning
  /// the normal turn flow (the next player's draw) can proceed.
  bool _resolveReactionsToLastDiscard() {
    while (true) {
      if (_state.isOver) return true;
      final priority = _reactionPriorityOrder();
      final viewerAlreadyDeclined = _viewerDeclinedCurrentReaction();

      for (final player in priority) {
        if (player == widget.viewerIndex && viewerAlreadyDeclined) continue;
        if (!_state.canDeclareRon(player)) continue;
        if (player == widget.viewerIndex) return true; // ロン button handles it.
        _state.declareRon(player);
        return true;
      }

      int? callPlayer;
      for (final player in priority) {
        if (player == widget.viewerIndex) {
          if (!viewerAlreadyDeclined &&
              (_state.canDeclarePon(player) || _state.canDeclareDaiminkan(player))) {
            return true; // ポン/カン button(s) handle it.
          }
          continue;
        }
        if (_state.canDeclareDaiminkan(player) || _state.canDeclarePon(player)) {
          callPlayer = player;
          break;
        }
      }
      if (callPlayer == null) return false; // nobody left to react to this discard.
      final player = callPlayer; // final — safe to capture in the closure below.

      final calledTile = _state.discardPiles[_state.lastDiscarderIndex].last;
      final handBeforeCall = _state.hands[player];
      final canKan = _state.canDeclareDaiminkan(player);
      final wantsKan = canKan &&
          shouldCall(handBeforeCall, _hypotheticalDaiminkanHand(player, calledTile), _cpuDifficulty);
      final canPon = !wantsKan && _state.canDeclarePon(player);
      final wantsPon =
          canPon && shouldCall(handBeforeCall, _hypotheticalPonHand(player, calledTile), _cpuDifficulty);

      if (wantsKan) {
        _trackHana(player, () => _state.declareDaiminkan(player));
      } else if (wantsPon) {
        _state.declarePon(player); // never itself draws.
      } else {
        return false; // eligible but not worth it — priority is spent either way.
      }
      if (_state.isOver) return true; // daiminkan's replacement draw could exhaust the wall.

      // The caller now owes an immediate discard of their own (an opened
      // hand can never riichi, so no riichi check here unlike _runCpuTurns).
      _state.discard(chooseDiscard(_state.currentHand));
      // Loop back around: this fresh discard might itself draw a reaction.
    }
  }

  /// Mirrors [GameState.declarePon]'s own claiming logic to preview the
  /// hand [player] would end up with by pon-ing [calledTile], without
  /// mutating engine state — used only to feed [shouldCall].
  Hand _hypotheticalPonHand(int player, Tile calledTile) {
    final hand = _state.hands[player];
    final concealed = List<Tile>.of(hand.concealedTiles);
    final claimed = <Tile>[];
    for (var i = concealed.length - 1; i >= 0 && claimed.length < 2; i--) {
      if (concealed[i].tileKind == calledTile.tileKind) claimed.add(concealed.removeAt(i));
    }
    final meld = Meld.kotsu([...claimed, calledTile], source: CallSource.pon);
    return Hand(concealedTiles: concealed, melds: [...hand.melds, meld]);
  }

  /// The 大明槓 counterpart to [_hypotheticalPonHand].
  Hand _hypotheticalDaiminkanHand(int player, Tile calledTile) {
    final hand = _state.hands[player];
    final concealed = List<Tile>.of(hand.concealedTiles);
    final claimed = <Tile>[];
    for (var i = concealed.length - 1; i >= 0 && claimed.length < 3; i--) {
      if (concealed[i].tileKind == calledTile.tileKind) claimed.add(concealed.removeAt(i));
    }
    final meld = Meld.kantsu([...claimed, calledTile], source: CallSource.daiminkan);
    return Hand(concealedTiles: concealed, melds: [...hand.melds, meld]);
  }

  void _ron() {
    setState(() {
      _hanaPopups = [];
      _state.declareRon(widget.viewerIndex);
    });
  }

  void _pon() {
    setState(() {
      _hanaPopups = [];
      _state.declarePon(widget.viewerIndex);
    });
  }

  void _kan() {
    setState(() {
      _hanaPopups = [];
      _trackHana(widget.viewerIndex, () => _state.declareDaiminkan(widget.viewerIndex));
    });
  }

  void _declineReaction() {
    setState(() {
      _hanaPopups = [];
      _declinedReactionDiscarderIndex = _state.lastDiscarderIndex;
      _declinedReactionPileLength = _state.discardPiles[_state.lastDiscarderIndex].length;
      _advanceAfterDiscard();
    });
  }

  void _declareTsumo() {
    setState(() {
      _hanaPopups = [];
      _state.declareTsumo();
    });
  }

  /// Applies the just-finished round to [widget.match] and, unless that
  /// was 半荘's last hand, deals and swaps in the next 局's [GameState] —
  /// only ever called when [widget.match] is non-null (see the "次局へ"
  /// button in [build]). Resets every piece of per-round UI state
  /// ([_riichiMode], the decline tracking, [_hanaPopups]) since none of it
  /// means anything against a brand new round.
  ///
  /// Needs the same [_runCpuTurns] call as [initState] and for the same
  /// reason: [match.dealCurrentRound] hands back a fresh deal that could
  /// just as easily start on a non-viewer dealer, and nothing else here
  /// draws for them.
  void _startNextRound() {
    final match = widget.match!;
    setState(() {
      match.advance(_state);
      _hanaPopups = [];
      _riichiMode = false;
      _declinedReactionDiscarderIndex = null;
      _declinedReactionPileLength = null;
      if (match.isOver) return;
      _state = match.dealCurrentRound(random: Random(), config: widget.config);
      _resolveKitaDecisionsForCpu();
      _runCpuTurns();
      _autoDrawForViewerIfNeeded();
    });
  }

  /// Resolves pending kita decisions using the CPU heuristic
  /// (`ai/kita_decision.dart`), stopping the instant it's the viewer's own
  /// turn to decide instead — their choice happens through the UI via
  /// [_nukiKita]/[_keepKita]. Used both mid-round (from [_runCpuTurns],
  /// where it's always already a CPU's turn) and for [initState]'s haipai
  /// kita sweep (where it might be the viewer's from the very first tile).
  void _resolveKitaDecisionsForCpu() {
    while (_state.hasPendingKitaDecision && _state.currentPlayerIndex != widget.viewerIndex) {
      final player = _state.currentPlayerIndex;
      final hypotheticalHand = Hand(
        concealedTiles: [..._state.currentHand.concealedTiles, _state.pendingKitaTile!],
        melds: _state.currentHand.melds,
      );
      if (shouldKeepDrawnKita(hypotheticalHand, _cpuDifficulty)) {
        _state.keepDrawnKita(); // never itself draws — nothing to _trackHana here.
      } else {
        _trackHana(player, _state.nukiKita);
      }
    }
  }

  /// Drives every other player's turn — resolve any kita decision, then
  /// tsumo if possible, otherwise a tile-efficiency discard (declaring
  /// riichi with it first if that discard would keep them tenpai) — until
  /// control returns to the viewer or the round ends.
  ///
  /// Only draws when [GameState.phase] is actually [TurnPhase.awaitingDraw]
  /// — [_advanceAfterDiscard]'s call always finds it there (the very
  /// definition of "next player's turn just started"), but
  /// [initState]/[_nukiKita]/[_keepKita] can hand this a CPU already at
  /// [TurnPhase.awaitingDiscard] instead (they just resolved their own
  /// kita decision and now owe a discard, no draw due) — drawing again
  /// there would violate [GameState]'s own phase precondition and throw.
  void _runCpuTurns() {
    while (!_state.isOver && _state.currentPlayerIndex != widget.viewerIndex) {
      if (_state.phase == TurnPhase.awaitingDraw) {
        _trackHana(_state.currentPlayerIndex, _state.drawForCurrentPlayer);
        if (_state.isOver) return; // exhaustive draw mid-loop.
        _resolveKitaDecisionsForCpu();
        if (_state.isOver) return; // exhaustive draw while resolving kita.
        if (_state.currentPlayerIndex == widget.viewerIndex) return; // landed on the viewer's own kita.
      }
      if (_state.canDeclareTsumo()) {
        _state.declareTsumo();
        return;
      }
      if (_state.riichiDeclared.contains(_state.currentPlayerIndex)) {
        // Already riichi'd — the hand is locked, so this is a forced
        // tsumogiri of whatever was just drawn, not a real choice.
        // GameState.discard enforces this itself (throws on anything
        // else), but chooseDiscard doesn't know about that constraint and
        // can suggest a different tile from the concealed hand.
        _state.discard(_state.currentHand.concealedTiles.last);
      } else {
        final discardTile = chooseDiscard(_state.currentHand);
        if (_state.canDeclareRiichiWith(discardTile)) {
          _state.declareRiichiAndDiscard(discardTile);
        } else {
          _state.discard(discardTile);
        }
      }
      if (_resolveReactionsToLastDiscard()) return; // round over, or viewer has a reaction.
    }
  }

  String _resultLabel(RoundResult result) => switch (result.reason) {
        RoundOverReason.tsumo => _tsumoResultLabel(result.winnerIndex!),
        RoundOverReason.ron => _ronResultLabel(result.winnerIndex!, result.dealtInIndex!),
        RoundOverReason.exhaustiveDraw => '終局: 流局',
      };

  String _tsumoResultLabel(int winner) {
    final base = '終局: プレイヤー$winnerのツモ和了';
    // The drawn tile is already part of the hand by the time tsumo can be
    // declared (GameState adds it on draw, before awaitingDiscard) — no
    // reconstruction needed, unlike ron.
    final points = _tryScoreWin(
      _state.hands[winner],
      winnerIsDealer: winner == _state.dealerIndex,
      method: WinMethod.tsumo,
    );
    if (points == null) return base;
    if (winner == _state.dealerIndex) {
      return '$base（${points.tsumoDoubleShare}点オール）';
    }
    final others = [
      for (var i = 0; i < _state.hands.length; i++)
        if (i != winner) i,
    ];
    final dealerOpponent = _state.dealerIndex;
    final otherOpponent = others.firstWhere((i) => i != dealerOpponent);
    return '$base（プレイヤー$dealerOpponentから${points.tsumoDoubleShare}点・'
        'プレイヤー$otherOpponentから${points.tsumoSingleShare}点）';
  }

  String _ronResultLabel(int winner, int dealtIn) {
    final base = '終局: プレイヤー$winnerのロン和了（放銃: プレイヤー$dealtIn）';
    // Unlike tsumo, GameState.declareRon never adds the discarded tile to
    // the winner's hand (it stays a historical record in the discarder's
    // pile) — score against a reconstructed complete hand instead.
    final winningTile = _state.discardPiles[dealtIn].last;
    final winnerHand = _state.hands[winner];
    final completeHand = Hand(
      concealedTiles: [...winnerHand.concealedTiles, winningTile],
      melds: winnerHand.melds,
    );
    final points = _tryScoreWin(
      completeHand,
      winnerIsDealer: winner == _state.dealerIndex,
      method: WinMethod.ron,
    );
    if (points == null) return base;
    return '$base（${points.ronPayment}点）';
  }

  /// Computes the win's points via [calculateWinPoints], or null if this
  /// module can't score it — the shape-only yaku detectors it's built on
  /// don't cover a riichi-only win (立直 alone, no other yaku), the one
  /// gap in an otherwise-exhaustive check ([GameState] itself already only
  /// let tsumo/ron happen for a complete hand with *some* yaku, shape-based
  /// or riichi).
  WinPoints? _tryScoreWin(Hand hand, {required bool winnerIsDealer, required WinMethod method}) {
    try {
      return calculateWinPoints(hand: hand, winnerIsDealer: winnerIsDealer, method: method);
    } on ArgumentError {
      return null;
    }
  }

  /// The 半荘 final-results screen, shown instead of the board once
  /// [MatchState.isOver] — ranked scores, nothing else (no "次局へ" to
  /// press, there is no next 局).
  Widget _buildMatchResultsScaffold(MatchState match) {
    final ranked = [
      for (var i = 0; i < match.scores.length; i++) (player: i, score: match.scores[i]),
    ]..sort((a, b) => b.score.compareTo(a.score));
    return Scaffold(
      appBar: AppBar(title: const Text('半荘終了')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('最終結果', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 12),
            for (var rank = 0; rank < ranked.length; rank++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text('${rank + 1}位: プレイヤー${ranked[rank].player}  ${ranked[rank].score}点'),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final match = widget.match;
    if (match != null && match.isOver) return _buildMatchResultsScaffold(match);

    final view = buildPlayerView(_state, viewerIndex: widget.viewerIndex);
    final isViewerTurn = !_state.isOver && _state.currentPlayerIndex == widget.viewerIndex;
    final canDiscard = isViewerTurn && _state.phase == TurnPhase.awaitingDiscard;
    final canTsumo = canDiscard && _state.canDeclareTsumo();
    final pendingKitaTile = isViewerTurn ? _state.pendingKitaTile : null;
    final canRon = _state.canDeclareRon(widget.viewerIndex);
    final canPon = _state.canDeclarePon(widget.viewerIndex);
    final canKan = _state.canDeclareDaiminkan(widget.viewerIndex);
    final canRiichi = canDiscard && _state.canDeclareRiichi;
    final ankanTile = canDiscard ? _ankanCandidate() : null;
    final shouminkanTile = canDiscard ? _shouminkanCandidate() : null;
    final result = _state.result;

    return Scaffold(
      appBar: AppBar(title: const Text('対局'), toolbarHeight: 40),
      // A plain (non-scrolling) Column, not a SingleChildScrollView: the
      // table gets whatever vertical space is left over via Expanded once
      // every other (fixed-height) row is laid out, so the whole screen —
      // rivers, hand, and any status/action rows — fits in one glance
      // without scrolling (STEP7 1画面完結レイアウト).
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (result != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _resultLabel(result),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                      if (match != null) ...[
                        const SizedBox(width: 8),
                        ElevatedButton(onPressed: _startNextRound, child: const Text('次局へ')),
                      ],
                    ],
                  ),
                ),
              if (_hanaPopups.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final popup in _hanaPopups)
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.pink.shade50,
                            border: Border.all(color: Colors.pink.shade200),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 26,
                                  child: FittedBox(fit: BoxFit.contain, child: TileView(popup.tile)),
                                ),
                                const SizedBox(width: 4),
                                Text('プレイヤー${popup.player}が${popup.tile.label}を抜きました'),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              Expanded(
                child: MahjongTableView(
                  view: view,
                  wallRemaining: _state.wall.remainingLiveCount,
                  scores: match?.scores,
                  roundLabel: match?.roundLabel,
                ),
              ),
              if (canRon || canPon || canKan)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      if (canRon) ...[
                        ElevatedButton(onPressed: _ron, child: const Text('ロン')),
                        const SizedBox(width: 8),
                      ],
                      if (canPon) ...[
                        ElevatedButton(onPressed: _pon, child: const Text('ポン')),
                        const SizedBox(width: 8),
                      ],
                      if (canKan) ...[
                        ElevatedButton(onPressed: _kan, child: const Text('カン')),
                        const SizedBox(width: 8),
                      ],
                      ElevatedButton(onPressed: _declineReaction, child: const Text('キャンセル')),
                    ],
                  ),
                ),
              if (pendingKitaTile != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      ElevatedButton(onPressed: _nukiKita, child: const Text('抜く')),
                      const SizedBox(width: 8),
                      ElevatedButton(onPressed: _keepKita, child: const Text('キャンセル')),
                    ],
                  ),
                ),
              Row(
                children: [
                  const Text('自分の手牌', style: TextStyle(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  if (canTsumo) ...[
                    ElevatedButton(onPressed: _declareTsumo, child: const Text('和了')),
                    const SizedBox(width: 8),
                  ],
                  if (canRiichi || _riichiMode) ...[
                    ElevatedButton(
                      onPressed: _toggleRiichiMode,
                      child: Text(_riichiMode ? 'リーチ選択中（キャンセル）' : 'リーチ'),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (ankanTile != null) ...[
                    ElevatedButton(onPressed: () => _ankan(ankanTile), child: const Text('暗槓')),
                    const SizedBox(width: 8),
                  ],
                  if (shouminkanTile != null)
                    ElevatedButton(onPressed: () => _shouminkan(shouminkanTile), child: const Text('加槓')),
                ],
              ),
              HandView(
                concealedTiles: pendingKitaTile == null
                    ? view.ownConcealedTiles
                    : [...view.ownConcealedTiles, pendingKitaTile],
                melds: view.melds[widget.viewerIndex],
                onDiscard: canDiscard ? _discard : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
