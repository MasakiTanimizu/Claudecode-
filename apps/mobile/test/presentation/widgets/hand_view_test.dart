import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_engine/mahjong_engine.dart';
import 'package:sanma_mobile/presentation/widgets/hand_view.dart';
import 'package:sanma_mobile/presentation/widgets/tile_view.dart';

void main() {
  testWidgets('renders one TileView per concealed tile plus meld tiles', (tester) async {
    final concealed = [
      NumberTile(NumberSuit.pin, 1),
      NumberTile(NumberSuit.pin, 2),
      NumberTile(NumberSuit.pin, 3),
    ];
    final melds = [
      Meld.kotsu(
        [DragonTile(Dragon.white), DragonTile(Dragon.white), DragonTile(Dragon.white)],
        source: CallSource.pon,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(home: HandView(concealedTiles: concealed, melds: melds)),
    );

    expect(find.byType(TileView), findsNWidgets(6)); // 3 concealed + 3 meld tiles.
  });
}
