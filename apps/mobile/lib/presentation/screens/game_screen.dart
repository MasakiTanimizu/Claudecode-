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
/// Whenever another player's discard is one the viewer could ron, pon,
/// and/or daiminkan, the game pauses right there — before the next player
/// would otherwise draw — and offers whichever of ロン/ポン/カン apply plus
/// a キャンセル to decline all of them ([_ron]/[_pon]/[_kan]/
/// [_declineReaction]); declining (or not being able to react at all)
/// resumes the normal flow.
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
/// Still out of scope here: the CPU stand-ins never call (pon/kan/ron) on
/// another player's discard, only riichi on their own turn; ankan/
/// shouminkan as a reaction to someone else's discard/kan (槍槓) isn't
/// modeled; there's no running score across rounds or a "next round" flow
/// — this screen only ever plays the one 局 it was dealt; and there's no
/// wait-tile highlighting or animation for a hana/kita tile itself moving
/// out of the hand (just the popup/badges above) — worth animating once
/// there's a reason to invest in it, not urgent before then.
class GameScreen extends StatefulWidget {
  final GameState state;
  final int viewerIndex;

  const GameScreen({required this.state, this.viewerIndex = 0, super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

const _cpuKitaDifficulty = CpuDifficulty.intermediate;

class _GameScreenState extends State<GameScreen> {
  GameState get _state => widget.state;

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
    // The one-time, dealer-first haipai kita sweep GameState.deal() already
    // ran and may be paused on any player, viewer included — resolve
    // whichever CPUs come first in it, same as mid-round, before drawing
    // for the viewer if it's already their turn. Can't setState this
    // early (the element isn't mounted yet) — mutate directly, since the
    // very first build() already reads fresh state.
    _resolveKitaDecisionsForCpu();
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
  /// [initState] — resolves whatever CPU haipai kita the sweep moves on
  /// to next, and draws for the viewer if the sweep lands back on them
  /// with the round properly under way. Without this, resolving the
  /// viewer's own haipai kita could leave the sweep paused on a CPU with
  /// no UI shown for it (not the viewer's turn) and nothing left to move
  /// it forward — the game would just stop.
  void _nukiKita() {
    setState(() {
      _hanaPopups = [];
      _trackHana(_state.currentPlayerIndex, _state.nukiKita);
      _resolveKitaDecisionsForCpu();
      _autoDrawForViewerIfNeeded();
    });
  }

  /// The keep-in-hand counterpart to [_nukiKita] — see its doc for why
  /// this also has to keep the haipai sweep moving afterward.
  void _keepKita() {
    setState(() {
      _hanaPopups = [];
      _state.keepDrawnKita(); // never itself draws — nothing to _trackHana here.
      _resolveKitaDecisionsForCpu();
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
  /// a CPU) — unless the viewer can ron, pon, and/or daiminkan it and
  /// hasn't already declined this exact discard, in which case this pauses
  /// right here so the UI can offer ロン/ポン/カン/キャンセル instead of
  /// silently moving on.
  void _advanceAfterDiscard() {
    if (_viewerCanReactToLastDiscard() && !_viewerDeclinedCurrentReaction()) return;
    _runCpuTurns();
    _autoDrawForViewerIfNeeded();
  }

  bool _viewerCanReactToLastDiscard() =>
      _state.canDeclareRon(widget.viewerIndex) ||
      _state.canDeclarePon(widget.viewerIndex) ||
      _state.canDeclareDaiminkan(widget.viewerIndex);

  bool _viewerDeclinedCurrentReaction() =>
      _declinedReactionDiscarderIndex == _state.lastDiscarderIndex &&
      _declinedReactionPileLength == _state.discardPiles[_state.lastDiscarderIndex].length;

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
      if (shouldKeepDrawnKita(hypotheticalHand, _cpuKitaDifficulty)) {
        _state.keepDrawnKita(); // never itself draws — nothing to _trackHana here.
      } else {
        _trackHana(player, _state.nukiKita);
      }
    }
  }

  /// Drives every other player's turn (draw, resolve any kita decision,
  /// then tsumo if possible, otherwise a tile-efficiency discard —
  /// declaring riichi with it first if that discard would keep them
  /// tenpai) until control returns to the viewer or the round ends.
  void _runCpuTurns() {
    while (!_state.isOver && _state.currentPlayerIndex != widget.viewerIndex) {
      _trackHana(_state.currentPlayerIndex, _state.drawForCurrentPlayer);
      if (_state.isOver) return; // exhaustive draw mid-loop.
      _resolveKitaDecisionsForCpu();
      if (_state.isOver) return; // exhaustive draw while resolving kita.
      if (_state.canDeclareTsumo()) {
        _state.declareTsumo();
        return;
      }
      final discardTile = chooseDiscard(_state.currentHand);
      if (_state.canDeclareRiichiWith(discardTile)) {
        _state.declareRiichiAndDiscard(discardTile);
      } else {
        _state.discard(discardTile);
      }
      if (_viewerCanReactToLastDiscard()) return; // pause for ロン/ポン/カン/キャンセル.
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

  @override
  Widget build(BuildContext context) {
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
                  child: Text(
                    _resultLabel(result),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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
                child: MahjongTableView(view: view, wallRemaining: _state.wall.remainingLiveCount),
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
