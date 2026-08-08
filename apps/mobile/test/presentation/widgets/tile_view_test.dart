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

  testWidgets('double-tap triggers onDiscard; a single tap does not', (tester) async {
    var discarded = false;
    await tester.pumpWidget(
      MaterialApp(
        home: TileView(NumberTile(NumberSuit.pin, 3), onDiscard: () => discarded = true),
      ),
    );

    await tester.tap(find.byType(TileView));
    await tester.pump();
    expect(discarded, isFalse);
    // Let the single tap's double-tap window fully expire so it can't be
    // mistaken for the first half of the double-tap sequence below.
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.byType(TileView));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byType(TileView));
    await tester.pump();
    expect(discarded, isTrue);
  });
}
