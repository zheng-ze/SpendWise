import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/transactions/delete_confirmation.dart';

Widget _host() => const MaterialApp(
  home: Scaffold(body: Builder(builder: _openButton)),
);

Widget _openButton(BuildContext context) =>
    TextButton(onPressed: () {}, child: const Text('open'));

void main() {
  testWidgets('shows the note when the entry has one', (tester) async {
    await tester.pumpWidget(_host());
    final context = tester.element(find.byType(TextButton));

    final future = showDeleteConfirmation(
      context,
      note: 'Coffee with Sam',
      title: 'Uncategorized',
    );
    await tester.pumpAndSettle();

    expect(find.text('Coffee with Sam'), findsOneWidget);
    expect(find.text('Delete this transaction?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await future;
  });

  testWidgets('falls back to the title when the note is empty', (tester) async {
    await tester.pumpWidget(_host());
    final context = tester.element(find.byType(TextButton));

    final future = showDeleteConfirmation(
      context,
      note: '',
      title: 'Groceries',
    );
    await tester.pumpAndSettle();

    expect(find.text('Groceries'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await future;
  });

  testWidgets('confirming returns true, cancelling returns false', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    final context = tester.element(find.byType(TextButton));

    final confirmed = showDeleteConfirmation(
      context,
      note: 'Note',
      title: 'Title',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(await confirmed, isTrue);

    final cancelled = showDeleteConfirmation(
      context,
      note: 'Note',
      title: 'Title',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(await cancelled, isFalse);
  });
}
