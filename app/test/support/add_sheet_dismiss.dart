import 'package:flutter_test/flutter_test.dart';

const _dismissDrag = Offset(0, 900);

Future<void> dismissAddSheet(WidgetTester tester) async {
  final cancel = find.text('Cancel');
  if (cancel.evaluate().isEmpty) {
    await tester.drag(find.text('Add entry'), _dismissDrag);
  } else {
    await tester.tap(cancel);
  }
  await tester.pumpAndSettle();
}
