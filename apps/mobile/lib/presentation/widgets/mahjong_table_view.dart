import 'package:flutter/material.dart';
import 'package:mahjong_engine/mahjong_engine.dart';
import 'package:shared_protocol/shared_protocol.dart';

import 'tile_view.dart';

/// A square 卓 (table) with each player's discard pile (河) laid out along
/// their own side, 雀魂-style — the viewer's river along the bottom edge,
/// the next player's along the right edge, and the player after that along
/// the left edge, each rotated to face the table's center. Each seat's
/// label also shows their nuku'd hana/kita tiles as small badges, so the
/// whole table — rivers, nuki tiles, wall count, dora — fits in one glance
/// without a separate list elsewhere on screen.
///
/// Sizes itself to whatever its parent gives it ([SizedBox.expand]) rather
/// than a fixed height, so callers can fit it into a non-scrolling layout
/// via [Expanded] alongside the rest of the screen (STEP7「対局画面」1画面
/// 完結レイアウト).
class MahjongTableView extends StatelessWidget {
  final PlayerView view;

  /// Tiles left in the live wall, shown in the center panel — purely
  /// display info from [GameState.wall], not part of [PlayerView] itself.
  final int wallRemaining;

  /// Running 半荘 scores, indexed by player — from [MatchState.scores] when
  /// a match is in progress, or null for a single-round session (in which
  /// case no score is shown on any seat).
  final List<int>? scores;

  /// E.g. "東1局 1本場" — from [MatchState.roundLabel], or null to omit it
  /// from the center panel (single-round session, same as [scores]).
  final String? roundLabel;

  const MahjongTableView({
    required this.view,
    required this.wallRemaining,
    this.scores,
    this.roundLabel,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final viewerIndex = view.viewerIndex;
    final rightIndex = (viewerIndex + 1) % view.discardPiles.length;
    final leftIndex = (viewerIndex + 2) % view.discardPiles.length;

    return SizedBox.expand(
      child: Container(
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
              child: _SeatLabel(playerIndex: leftIndex, view: view, score: scores?[leftIndex]),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: _SeatLabel(playerIndex: rightIndex, view: view, score: scores?[rightIndex]),
            ),
            Positioned(
              bottom: 8,
              left: 8,
              child: _SeatLabel(playerIndex: viewerIndex, view: view, score: scores?[viewerIndex]),
            ),
            Align(
              child: _CenterInfoPanel(view: view, wallRemaining: wallRemaining, roundLabel: roundLabel),
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
      ),
    );
  }
}

/// The table's center card: round/turn status plus wall and dora info —
/// everything that isn't tied to one specific seat.
class _CenterInfoPanel extends StatelessWidget {
  final PlayerView view;
  final int wallRemaining;
  final String? roundLabel;

  const _CenterInfoPanel({required this.view, required this.wallRemaining, this.roundLabel});

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(color: Colors.white, fontSize: 11);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (roundLabel != null) ...[
            Text(roundLabel!, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
          ],
          Text('山: $wallRemaining枚', style: style),
          const SizedBox(height: 4),
          Text(
            'ドラ表示: ${view.doraIndicators.map((t) => t.label).join(' ')}',
            style: style,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            '手番: プレイヤー${view.currentPlayerIndex}  局面: ${view.phase.name}',
            style: style,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _SeatLabel extends StatelessWidget {
  final int playerIndex;
  final PlayerView view;

  /// This seat's running 半荘 score, or null to omit it (single-round
  /// session — see [MahjongTableView.scores]).
  final int? score;

  const _SeatLabel({required this.playerIndex, required this.view, this.score});

  @override
  Widget build(BuildContext context) {
    final seatLabel = playerIndex == view.dealerIndex
        ? 'プレイヤー$playerIndex（親）'
        : 'プレイヤー$playerIndex';
    final label = score == null ? seatLabel : '$seatLabel $score点';
    final isRiichi = view.riichiPlayers.contains(playerIndex);
    final isTurn = view.currentPlayerIndex == playerIndex;
    final nuki = view.nukiTiles[playerIndex];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
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
        ),
        if (nuki.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: SizedBox(
              height: 22,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final tile in nuki)
                    SizedBox(
                      width: 16,
                      height: 22,
                      child: FittedBox(fit: BoxFit.contain, child: TileView(tile)),
                    ),
                ],
              ),
            ),
          ),
      ],
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
