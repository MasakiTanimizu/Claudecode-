import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_engine/mahjong_engine.dart';
import 'package:sanma_mobile/presentation/widgets/hand_view.dart';
import 'package:sanma_mobile/presentation/widgets/tile_view.dart';

NumberTile pin(int n) => NumberTile(NumberSuit.pin, n);
NumberTile sou(int n) => NumberTile(NumberSuit.sou, n);
NumberTile man(int n) => NumberTile(NumberSuit.man, n);

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

  testWidgets('double-tapping a concealed tile calls onDiscard with that tile', (tester) async {
    final target = NumberTile(NumberSuit.pin, 2);
    Tile? discarded;

    await tester.pumpWidget(
      MaterialApp(
        home: HandView(
          concealedTiles: [NumberTile(NumberSuit.pin, 1), target],
          melds: const [],
          onDiscard: (tile) => discarded = tile,
        ),
      ),
    );

    await tester.tap(find.text('2p'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('2p'));
    await tester.pump();

    expect(discarded, target);
    // Flush the gesture recognizer's own internal timer so the test
    // framework doesn't see it as still pending at teardown.
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('auto-sorts concealed tiles into man → pin → sou → winds → dragons → kita', (tester) async {
    final concealed = [
      const KitaTile(),
      DragonTile(Dragon.red),
      const WindTile(Wind.south),
      sou(2),
      pin(9),
      man(9),
      pin(1),
      man(1),
    ];

    await tester.pumpWidget(
      MaterialApp(home: HandView(concealedTiles: concealed, melds: const [])),
    );

    final labels = tester
        .widgetList<TileView>(find.byType(TileView))
        .map((view) => view.tile.label)
        .toList();

    expect(labels, ['1m', '9m', '1p', '9p', '2s', '南', '中', '北']);
  });

  testWidgets('meld tiles keep their declared order, unaffected by concealed-tile sorting', (tester) async {
    final concealed = [pin(9), pin(1)];
    final melds = [
      Meld.kotsu(
        [DragonTile(Dragon.white), DragonTile(Dragon.white), DragonTile(Dragon.white)],
        source: CallSource.pon,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(home: HandView(concealedTiles: concealed, melds: melds)),
    );

    final labels = tester
        .widgetList<TileView>(find.byType(TileView))
        .map((view) => view.tile.label)
        .toList();

    expect(labels, ['1p', '9p', '白', '白', '白']);
  });
}
