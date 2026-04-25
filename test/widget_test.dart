import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cardiva/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: CardivApp()));
    await tester.pumpAndSettle();
    expect(find.byType(CardivApp), findsOneWidget);
  });
}