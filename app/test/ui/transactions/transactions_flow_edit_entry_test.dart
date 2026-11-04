import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/transactions/entry/entry_form_view_model.dart';
import 'package:spendwise/ui/transactions/transactions_flow.dart';

import '../../support/edit_entry_harness.dart';
import '../../support/pump_app.dart';
import '../../support/ui_test_timeout.dart';

const _scopeTitle = 'Checking';
const _editTitle = 'Edit entry';
const _updateLabel = 'Update entry';
const _newAmount = '42';
const _newAmountText = '42.00';

Future<void> _pumpScopedFlow(WidgetTester tester, Entry entry) async {
  final scope = TransactionsScope(
    title: _scopeTitle,
    scopeIDs: {editChecking.id},
  );
  await pumpApp(
    tester,
    TransactionsFlow(initialScope: scope),
    ledger: editLedger([entry]),
  );
  addTearDown(() => closeAllSheets(tester));
}

Future<void> _tapRow(WidgetTester tester, Entry entry) async {
  await tester.tap(find.text(entry.name));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('tapping a register row installs an Edit entry sheet', (
    tester,
  ) async {
    final entry = editableEntry();
    await _pumpScopedFlow(tester, entry);

    await _tapRow(tester, entry);

    expect(find.byType(AppSheet), findsOneWidget);
    expect(find.text(_editTitle), findsOneWidget);
  }, timeout: uiTestTimeout);

  testWidgets(
    'saving then reopening the same row opens a fresh editable form',
    (tester) async {
      final entry = editableEntry();
      await _pumpScopedFlow(tester, entry);
      await _tapRow(tester, entry);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(TransactionsFlow)),
      );

      container
          .read(entryFormViewModelProvider(entry.id).notifier)
          .setAmount(_newAmount);
      await tester.pumpAndSettle();
      await tester.tap(find.text(_updateLabel));
      await tester.pumpAndSettle();
      expect(find.byType(AppSheet), findsNothing);
      await _tapRow(tester, entry);

      final amountField = tester.widget<EditableText>(
        find.byType(EditableText).first,
      );
      expect(find.text(_editTitle), findsOneWidget);
      expect(amountField.controller.text, _newAmountText);
    },
    timeout: uiTestTimeout,
  );
}
