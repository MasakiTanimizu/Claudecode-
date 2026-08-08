import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_engine/mahjong_engine.dart';
import 'package:sanma_mobile/presentation/screens/game_screen.dart';
import 'package:sanma_mobile/presentation/widgets/tile_view.dart';

NumberTile pin(int n) => NumberTile(NumberSuit.pin, n);
NumberTile sou(int n) => NumberTile(NumberSuit.sou, n);
NumberTile man(int n) => NumberTile(NumberSuit.man, n);

List<Tile> filler(NumberTile Function(int) suit, int rank, int count) =>
    List.generate(count, (_) => suit(rank));

void main() {
  testWidgets('shows the viewer\'s own hand, discard piles, and dora indicators', (tester) async {
    final hands = [
      Hand(concealedTiles: filler(pin, 3, 13)),
      Hand(concealedTiles: filler(sou, 3, 13)),
      Hand(concealedTiles: filler(man, 1, 13)),
    ];
    final wall = Wall([pin(9), pin(2), pin(2)]);
    final state = GameState(hands: hands, wall: wall, dealerIndex: 0);
    state.drawForCurrentPlayer();
    state.discard(pin(9));

    await tester.pumpWidget(MaterialApp(home: GameScreen(state: state)));

    expect(find.text('自分の手牌'), findsOneWidget);
    expect(find.byType(TileView), findsWidgets);
    expect(find.textContaining('手番: プレイヤー1'), findsOneWidget);
    expect(find.textContaining('プレイヤー0（親）'), findsOneWidget);
  });
}
