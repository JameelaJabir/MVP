import 'package:flutter_test/flutter_test.dart';
import 'package:test_app/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const EpicPadelApp());
    await tester.pumpAndSettle();
    expect(find.text('epic.'), findsOneWidget);
  });
}
