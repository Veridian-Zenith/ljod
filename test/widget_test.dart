import 'package:flutter_test/flutter_test.dart';
import 'package:ljod/main.dart';

void main() {
  testWidgets('LjodApp smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const LjodApp());

    // Verify that our library stub loads.
    expect(find.text('Ljod Library (Flutter Rewrite)'), findsOneWidget);
  });
}
