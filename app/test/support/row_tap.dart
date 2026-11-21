import 'package:flutter_test/flutter_test.dart';

Future<void> tapRow(
  WidgetTester tester,
  Finder row, {
  bool scrollIntoView = false,
}) async {
  if (scrollIntoView) {
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
  }
  await tester.tap(row);
  await tester.pumpAndSettle();
}
