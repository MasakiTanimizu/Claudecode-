import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_engine/mahjong_engine.dart';
import 'package:sanma_mobile/presentation/widgets/tile_view.dart';

void main() {
  testWidgets('renders the tile\'s label', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: TileView(NumberTile(NumberSuit.pin, 5, mark: TileMark.red))),
    );

    expect(find.text('5p(赤)'), findsOneWidget);
  });

  testWidgets('renders 北 correctly', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: TileView(KitaTile())));

    expect(find.text('北'), findsOneWidget);
  });
}
