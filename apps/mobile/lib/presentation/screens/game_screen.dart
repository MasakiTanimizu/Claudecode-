import 'package:flutter/material.dart';
import 'package:mahjong_engine/mahjong_engine.dart';
import 'package:shared_protocol/shared_protocol.dart';

import '../widgets/discard_pile_view.dart';
import '../widgets/hand_view.dart';

/// Static board display for one player's view of a [GameState] (STEP7
/// 「対局画面」). Read-only for now — tapping a hand tile to discard, riichi/
/// tsumo/ron/pon/kan actions, and wait-tile highlighting are later slices
/// layered on top of this same board.
class GameScreen extends StatelessWidget {
  final GameState state;
  final int viewerIndex;

  const GameScreen({required this.state, this.viewerIndex = 0, super.key});

  @override
  Widget build(BuildContext context) {
    final view = buildPlayerView(state, viewerIndex: viewerIndex);

    return Scaffold(
      appBar: AppBar(title: const Text('対局')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ドラ表示: ${view.doraIndicators.map((t) => t.label).join(' ')}'),
            Text('手番: プレイヤー${view.currentPlayerIndex}  局面: ${view.phase.name}'),
            const SizedBox(height: 12),
            for (var i = 0; i < view.discardPiles.length; i++) ...[
              DiscardPileView(
                playerLabel: i == view.dealerIndex ? 'プレイヤー$i（親）' : 'プレイヤー$i',
                discards: view.discardPiles[i],
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 16),
            const Text('自分の手牌', style: TextStyle(fontWeight: FontWeight.bold)),
            HandView(
              concealedTiles: view.ownConcealedTiles,
              melds: view.melds[viewerIndex],
            ),
          ],
        ),
      ),
    );
  }
}
