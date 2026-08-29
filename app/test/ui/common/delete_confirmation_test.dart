import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/common/delete_confirmation.dart';

Widget _host() => const MaterialApp(
  home: Scaffold(body: Builder(builder: _openButton)),
);

Widget _openButton(BuildContext context) =>
    TextButton(onPressed: () {}, child: const Text('open'));

void main() {
  testWidgets('shows the item name in the dialog title', (tester) async {
    await tester.pumpWidget(_host());
    final context = tester.element(find.byType(TextButton));

    final future = showDeleteConfirmation(context, itemName: 'Groceries');
    await tester.pumpAndSettle();

    expect(find.text('Delete Groceries?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await future;
  });

  testWidgets('confirming returns true, cancelling returns false', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    final context = tester.element(find.byType(TextButton));

    final confirmed = showDeleteConfirmation(context, itemName: 'Item');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(await confirmed, isTrue);

    final cancelled = showDeleteConfirmation(context, itemName: 'Item');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(await cancelled, isFalse);
  });
}
