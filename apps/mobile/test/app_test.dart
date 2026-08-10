import 'package:flutter_test/flutter_test.dart';
import 'package:sanma_mobile/app/app.dart';
import 'package:sanma_mobile/presentation/screens/game_screen.dart';

void main() {
  testWidgets('renders the home screen with the app title and start button', (tester) async {
    await tester.pumpWidget(const SanmaMahjongApp());

    expect(find.text('6華6北5等三麻'), findsOneWidget);
    expect(find.text('対局開始（動作確認用）'), findsOneWidget);
  });

  testWidgets('tapping the start button deals a round and opens the game screen', (tester) async {
    await tester.pumpWidget(const SanmaMahjongApp());

    await tester.tap(find.text('対局開始（動作確認用）'));
    await tester.pumpAndSettle();

    expect(find.byType(GameScreen), findsOneWidget);
    expect(find.text('自分の手牌'), findsOneWidget);
  });
}
