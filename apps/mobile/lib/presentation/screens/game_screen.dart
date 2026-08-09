import 'package:flutter/material.dart';
import 'package:mahjong_engine/mahjong_engine.dart';
import 'package:shared_protocol/shared_protocol.dart';

import '../widgets/discard_pile_view.dart';
import '../widgets/hand_view.dart';
import '../widgets/mahjong_table_view.dart';

/// One player's view of a live [GameState] (STEP7「対局画面」), interactive
/// for the viewer's own turn: the viewer's draw happens automatically (no
/// manual "ツモ" button — drawing carries no decision, unlike discarding),
/// then they double-tap a tile to discard, declare tsumo when available,
/// declare riichi ([_toggleRiichiMode] then double-tap a tenpai-preserving
/// tile), declare 暗槓/加槓 when their hand allows it ([_ankan]/
/// [_shouminkan]), or resolve a kita (抜く/キャンセル, i.e. keep it in hand)
/// whenever one comes up — including any dealt straight into their opening
/// hand, which [GameState] offers the exact same choice for as one drawn
/// mid-round. The other two players are driven locally by the tile-
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
/// Still out of scope here: the CPU stand-ins never call (pon/kan/ron) on
/// another player's discard, only riichi on their own turn; ankan/
/// shouminkan as a reaction to someone else's discard/kan (槍槓) isn't
/// modeled; and there's no wait-tile highlighting or visible animation for
/// a hana/kita being nuku'd (each player's own 抜き牌 list on the table is
/// the only record for now — worth animating once there's real tile art,
/// not urgent before then).
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
      _state.drawForCurrentPlayer();
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
      _state.nukiKita();
      _resolveKitaDecisionsForCpu();
      _autoDrawForViewerIfNeeded();
    });
  }

  /// The keep-in-hand counterpart to [_nukiKita] — see its doc for why
  /// this also has to keep the haipai sweep moving afterward.
  void _keepKita() {
    setState(() {
      _state.keepDrawnKita();
      _resolveKitaDecisionsForCpu();
      _autoDrawForViewerIfNeeded();
    });
  }

  void _discard(Tile tile) {
    if (_riichiMode) {
      if (!_state.canDeclareRiichiWith(tile)) return; // only a tenpai-preserving tile is valid.
      setState(() {
        _state.declareRiichiAndDiscard(tile);
        _riichiMode = false;
        _advanceAfterDiscard();
      });
      return;
    }
    setState(() {
      _state.discard(tile);
      _advanceAfterDiscard();
    });
  }

  void _toggleRiichiMode() {
    setState(() => _riichiMode = !_riichiMode);
  }

  void _ankan(Tile tile) {
    setState(() {
      _state.declareAnkan(tile);
      _riichiMode = false; // the hand just changed; any pending riichi pick is stale.
    });
  }

  void _shouminkan(Tile tile) {
    setState(() {
      _state.declareShouminkan(tile);
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
    setState(() => _state.declareRon(widget.viewerIndex));
  }

  void _pon() {
    setState(() => _state.declarePon(widget.viewerIndex));
  }

  void _kan() {
    setState(() => _state.declareDaiminkan(widget.viewerIndex));
  }

  void _declineReaction() {
    setState(() {
      _declinedReactionDiscarderIndex = _state.lastDiscarderIndex;
      _declinedReactionPileLength = _state.discardPiles[_state.lastDiscarderIndex].length;
      _advanceAfterDiscard();
    });
  }

  void _declareTsumo() {
    setState(_state.declareTsumo);
  }

  /// Resolves pending kita decisions using the CPU heuristic
  /// (`ai/kita_decision.dart`), stopping the instant it's the viewer's own
  /// turn to decide instead — their choice happens through the UI via
  /// [_nukiKita]/[_keepKita]. Used both mid-round (from [_runCpuTurns],
  /// where it's always already a CPU's turn) and for [initState]'s haipai
  /// kita sweep (where it might be the viewer's from the very first tile).
  void _resolveKitaDecisionsForCpu() {
    while (_state.hasPendingKitaDecision && _state.currentPlayerIndex != widget.viewerIndex) {
      final hypotheticalHand = Hand(
        concealedTiles: [..._state.currentHand.concealedTiles, _state.pendingKitaTile!],
        melds: _state.currentHand.melds,
      );
      if (shouldKeepDrawnKita(hypotheticalHand, _cpuKitaDifficulty)) {
        _state.keepDrawnKita();
      } else {
        _state.nukiKita();
      }
    }
  }

  /// Drives every other player's turn (draw, resolve any kita decision,
  /// then tsumo if possible, otherwise a tile-efficiency discard —
  /// declaring riichi with it first if that discard would keep them
  /// tenpai) until control returns to the viewer or the round ends.
  void _runCpuTurns() {
    while (!_state.isOver && _state.currentPlayerIndex != widget.viewerIndex) {
      _state.drawForCurrentPlayer();
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
        RoundOverReason.tsumo => '終局: プレイヤー${result.winnerIndex}のツモ和了',
        RoundOverReason.ron =>
          '終局: プレイヤー${result.winnerIndex}のロン和了（放銃: プレイヤー${result.dealtInIndex}）',
        RoundOverReason.exhaustiveDraw => '終局: 流局',
      };

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
      appBar: AppBar(title: const Text('対局')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (result != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _resultLabel(result),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            MahjongTableView(view: view),
            const SizedBox(height: 12),
            for (var i = 0; i < view.nukiTiles.length; i++)
              if (view.nukiTiles[i].isNotEmpty) ...[
                DiscardPileView(
                  playerLabel: 'プレイヤー$iの抜き牌',
                  discards: view.nukiTiles[i],
                ),
                const SizedBox(height: 8),
              ],
            if (canRon || canPon || canKan)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
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
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    ElevatedButton(onPressed: _nukiKita, child: const Text('抜く')),
                    const SizedBox(width: 8),
                    ElevatedButton(onPressed: _keepKita, child: const Text('キャンセル')),
                  ],
                ),
              ),
            const SizedBox(height: 16),
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
              concealedTiles: view.ownConcealedTiles,
              melds: view.melds[widget.viewerIndex],
              onDiscard: canDiscard ? _discard : null,
            ),
          ],
        ),
      ),
    );
  }
}
