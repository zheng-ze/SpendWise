import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/common/delete_confirmation.dart';
import 'package:spendwise/ui/theme/spendwise_colors.dart';
import 'package:spendwise/ui/theme/spendwise_theme.dart';

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

  testWidgets('the dialog uses tokens with an error-filled confirm', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildSpendWiseTheme(Brightness.light),
        home: const Scaffold(body: Builder(builder: _openButton)),
      ),
    );
    final context = tester.element(find.byType(TextButton));
    final tokens = Theme.of(context).extension<SpendWiseColors>()!;

    final future = showDeleteConfirmation(context, itemName: 'Item');
    await tester.pumpAndSettle();

    final dialog = tester.widget<Dialog>(find.byType(Dialog));
    expect(dialog.backgroundColor, tokens.raised);
    final shape = dialog.shape! as RoundedRectangleBorder;
    expect(shape.side.color, tokens.control);
    final confirm = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Delete'),
    );
    expect(confirm.style?.backgroundColor?.resolve({}), tokens.error);
    expect(confirm.style?.foregroundColor?.resolve({}), tokens.onAction);

    await tester.tap(find.text('Delete'));
    await future;
  });
}
