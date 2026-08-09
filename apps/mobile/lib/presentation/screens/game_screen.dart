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
/// Still out of scope here: riichi, ron, pon, kan, and any wait-tile
/// highlighting — the viewer can only draw/discard/tsumo/kita-decide for
/// now, and the CPU stand-ins never riichi/call either (STEP8's fuller
/// decision flow layers on top of this same loop in a later slice).
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

  @override
  void initState() {
    super.initState();
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

  void _nukiKita() {
    setState(_state.nukiKita);
  }

  void _keepKita() {
    setState(_state.keepDrawnKita);
  }

  void _discard(Tile tile) {
    setState(() {
      _state.discard(tile);
      _runCpuTurns();
      _autoDrawForViewerIfNeeded();
    });
  }

  void _declareTsumo() {
    setState(_state.declareTsumo);
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
