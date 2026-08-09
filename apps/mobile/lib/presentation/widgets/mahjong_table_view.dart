import 'package:flutter/material.dart';
import 'package:mahjong_engine/mahjong_engine.dart';
import 'package:shared_protocol/shared_protocol.dart';

import 'tile_view.dart';

/// A square 卓 (table) with each player's discard pile (河) laid out along
/// their own side, 雀魂-style — the viewer's river along the bottom edge,
/// the next player's along the right edge, and the player after that along
/// the left edge, each rotated to face the table's center.
class MahjongTableView extends StatelessWidget {
  final PlayerView view;

  const MahjongTableView({required this.view, super.key});

  @override
  Widget build(BuildContext context) {
    final viewerIndex = view.viewerIndex;
    final rightIndex = (viewerIndex + 1) % view.discardPiles.length;
    final leftIndex = (viewerIndex + 2) % view.discardPiles.length;

    return Container(
      height: 320,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF175C3A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF6B4A2B), width: 8),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 8,
            left: 8,
            child: _SeatLabel(playerIndex: leftIndex, view: view),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: _SeatLabel(playerIndex: rightIndex, view: view),
          ),
          Positioned(
            bottom: 8,
            left: 8,
            child: _SeatLabel(playerIndex: viewerIndex, view: view),
          ),
          Align(
            child: Text(
              'ドラ表示: ${view.doraIndicators.map((t) => t.label).join(' ')}\n'
              '手番: プレイヤー${view.currentPlayerIndex}  局面: ${view.phase.name}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
          ),
          Positioned(
            left: 48,
            top: 0,
            bottom: 0,
            child: Center(
              child: RotatedBox(
                quarterTurns: 1,
                child: _RiverWrap(tiles: view.discardPiles[leftIndex]),
              ),
            ),
          ),
          Positioned(
            right: 48,
            top: 0,
            bottom: 0,
            child: Center(
              child: RotatedBox(
                quarterTurns: 3,
                child: _RiverWrap(tiles: view.discardPiles[rightIndex]),
              ),
            ),
          ),
          Positioned(
            bottom: 8,
            left: 56,
            right: 56,
            child: Center(
              child: _RiverWrap(tiles: view.discardPiles[viewerIndex]),
            ),
          ),
        ],
      ),
    );
  }
}

class _SeatLabel extends StatelessWidget {
  final int playerIndex;
  final PlayerView view;

  const _SeatLabel({required this.playerIndex, required this.view});

  @override
  Widget build(BuildContext context) {
    final label = playerIndex == view.dealerIndex
        ? 'プレイヤー$playerIndex（親）'
        : 'プレイヤー$playerIndex';
    final isRiichi = view.riichiPlayers.contains(playerIndex);
    final isTurn = view.currentPlayerIndex == playerIndex;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isTurn ? Colors.amber.withValues(alpha: 0.85) : Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Text(
          isRiichi ? '$label 立直' : label,
          style: TextStyle(color: isTurn ? Colors.black : Colors.white, fontSize: 12),
        ),
      ),
    );
  }
}

class _RiverWrap extends StatelessWidget {
  final List<Tile> tiles;

  const _RiverWrap({required this.tiles});

  @override
  Widget build(BuildContext context) {
    return Wrap(children: [for (final tile in tiles) TileView(tile)]);
  }
}
