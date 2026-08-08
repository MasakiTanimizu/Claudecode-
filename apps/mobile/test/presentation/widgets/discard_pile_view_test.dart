import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_engine/mahjong_engine.dart';
import 'package:sanma_mobile/presentation/widgets/discard_pile_view.dart';
import 'package:sanma_mobile/presentation/widgets/tile_view.dart';

void main() {
  testWidgets('renders the player label and each discarded tile', (tester) async {
    final discards = [
      NumberTile(NumberSuit.sou, 4),
      NumberTile(NumberSuit.sou, 5),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: DiscardPileView(playerLabel: 'プレイヤー1', discards: discards),
      ),
    );

    expect(find.text('プレイヤー1'), findsOneWidget);
    expect(find.byType(TileView), findsNWidgets(2));
  });
}
