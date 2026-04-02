import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/main.dart'; // Keep this relative path

void main() {
  testWidgets('Admin Dashboard shows title', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // Verify that the "Admin Dashboard" text exists
    expect(find.text('Alumni Dashboard'), findsOneWidget);
  });
}