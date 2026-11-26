import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rapih_ui/main.dart';
import 'package:rapih_ui/providers/app_state.dart';

void main() {
  testWidgets('Rapih Euy app renders smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AppState()),
        ],
        child: const RapihEuyApp(),
      ),
    );

    expect(find.byType(RapihEuyApp), findsOneWidget);
  });
}
