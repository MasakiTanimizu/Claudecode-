import 'package:flutter_test/flutter_test.dart';
import 'package:sanma_mobile/app/app.dart';

void main() {
  testWidgets('renders the home screen with the app title', (tester) async {
    await tester.pumpWidget(const SanmaMahjongApp());

    expect(find.text('6華6北5等三麻'), findsOneWidget);
    expect(find.text('準備中'), findsOneWidget);
  });
}
