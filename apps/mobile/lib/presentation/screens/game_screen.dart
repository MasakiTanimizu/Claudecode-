import 'package:flutter/material.dart';
import 'package:mahjong_engine/mahjong_engine.dart';
import 'package:shared_protocol/shared_protocol.dart';

import '../widgets/discard_pile_view.dart';
import '../widgets/hand_view.dart';
import '../widgets/mahjong_table_view.dart';

/// One player's view of a live [GameState] (STEP7「対局画面」), interactive
/// for the viewer's own turn: the viewer's draw happens automatically (no
/// manual "ツモ" button — drawing carries no decision, unlike discarding),
/// then they double-tap a tile to discard, declare tsumo when available, or
/// resolve a drawn kita (抜く/残す) when one comes up. The other two players
/// are driven locally by the tile-efficiency CPU baseline
/// (`ai/heuristic_discard.dart` and `ai/kita_decision.dart`) right after the
/// viewer's discard, so a full round actually plays out. Hana tiles never
/// reach here as a decision — [GameState] auto-nuku's them.
///
/// Whenever another player's discard is one the viewer could ron, pon,
/// and/or daiminkan, the game pauses right there — before the next player
/// would otherwise draw — and offers whichever of ロン/ポン/カン apply plus
/// a キャンセル to decline all of them ([_ron]/[_pon]/[_kan]/
/// [_declineReaction]); declining (or not being able to react at all)
/// resumes the normal flow.
///
/// Every hana/kita auto-nuku'd by any player — which otherwise happens
/// silently inside [GameState], invisible frame-to-frame — pops a SnackBar
/// naming the tile the instant it happens (STEP7フィードバック改善: 何が
/// 起きたか分かるように), on top of the persistent per-player 抜き牌 list
/// already shown on the table.
///
/// Still out of scope here: riichi, ankan/shouminkan reactions, and any
/// wait-tile highlighting — the CPU stand-ins never riichi/call/ron
/// either (STEP8's fuller decision flow layers on top of this same loop
/// in a later slice).
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

  @override
  void initState() {
    super.initState();
    // Can't setState this early (the element isn't mounted yet) — mutate
    // directly, since the very first build() already reads fresh state,
    // and defer the SnackBar until a frame has actually gone up.
    final before = _nukiCounts();
    _autoDrawForViewerIfNeeded();
    WidgetsBinding.instance.addPostFrameCallback((_) => _announceNewNuki(before));
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

  /// Runs [action] as a [setState] and, if it caused any player's hana/kita
  /// to get auto-nuku'd along the way, announces each one via a SnackBar —
  /// otherwise a hana quietly vanishing off the top of the wall (or a kita
  /// nuku'd mid CPU-turn-chain) is easy to miss entirely.
  void _runStateChange(void Function() action) {
    final before = _nukiCounts();
    setState(action);
    _announceNewNuki(before);
  }

  List<int> _nukiCounts() => [for (final tiles in _state.nukiTiles) tiles.length];

  void _announceNewNuki(List<int> before) {
    if (!mounted) return;
    final messages = <String>[];
    for (var player = 0; player < _state.nukiTiles.length; player++) {
      final newTiles = _state.nukiTiles[player].sublist(before[player]);
      if (newTiles.isEmpty) continue;
      final who = player == widget.viewerIndex ? '自分' : 'プレイヤー$player';
      messages.add('$whoが${newTiles.map((t) => t.label).join('・')}を抜きました');
    }
    if (messages.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(messages.join(' / ')), duration: const Duration(seconds: 2)),
    );
  }

  void _nukiKita() {
    _runStateChange(_state.nukiKita);
  }

  void _keepKita() {
    _runStateChange(_state.keepDrawnKita);
  }

  void _discard(Tile tile) {
    _runStateChange(() {
      _state.discard(tile);
      _advanceAfterDiscard();
    });
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
    _runStateChange(() => _state.declareRon(widget.viewerIndex));
  }

  void _pon() {
    _runStateChange(() => _state.declarePon(widget.viewerIndex));
  }

  void _kan() {
    _runStateChange(() => _state.declareDaiminkan(widget.viewerIndex));
  }

  void _declineReaction() {
    _runStateChange(() {
      _declinedReactionDiscarderIndex = _state.lastDiscarderIndex;
      _declinedReactionPileLength = _state.discardPiles[_state.lastDiscarderIndex].length;
      _advanceAfterDiscard();
    });
  }

  void _declareTsumo() {
    _runStateChange(_state.declareTsumo);
  }

  /// Resolves every pending kita decision for the current player using the
  /// CPU heuristic (`ai/kita_decision.dart`). Only called for the CPU
  /// stand-ins — the viewer instead gets an explicit UI choice via
  /// [_nukiKita]/[_keepKita].
  void _resolveKitaDecisionsForCpu() {
    while (_state.hasPendingKitaDecision) {
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
  /// then tsumo if possible, otherwise a tile-efficiency discard) until
  /// control returns to the viewer or the round ends.
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
      _state.discard(chooseDiscard(_state.currentHand));
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
                    Text('北を引きました（${pendingKitaTile.label}）: 抜きますか、残しますか？'),
                    const SizedBox(width: 8),
                    ElevatedButton(onPressed: _nukiKita, child: const Text('抜く')),
                    const SizedBox(width: 8),
                    ElevatedButton(onPressed: _keepKita, child: const Text('残す')),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('自分の手牌', style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                if (canTsumo) ...[
                  const SizedBox(width: 8),
                  ElevatedButton(onPressed: _declareTsumo, child: const Text('和了')),
                ],
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
