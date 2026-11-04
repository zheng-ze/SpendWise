import 'dart:async';

import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/transactions/entry/edit_entry_presenter.dart';
import 'package:spendwise/ui/transactions/entry/entry_form_view_model.dart';

import '../../../support/add_sheet_dismiss.dart';
import '../../../support/edit_entry_harness.dart';
import '../../../support/ui_test_timeout.dart';

const _editTitle = 'Edit entry';
const _deleteKey = ValueKey('edit-entry-delete');

Future<void> _open(WidgetTester tester, EditHost host, Entry entry) async {
  unawaited(
    openEditEntry(context: host.context, ref: host.ref, entryId: entry.id),
  );
  await tester.pumpAndSettle();
}

EntryFormNotifier _form(EditHost host, Entry entry) =>
    host.container.read(entryFormViewModelProvider(entry.id).notifier);

EntryFormViewState _state(EditHost host, Entry entry) =>
    host.container.read(entryFormViewModelProvider(entry.id)).value!;

void main() {
  testWidgets('Update entry saves and the route completes', (tester) async {
    final entry = editableEntry();
    final ledger = editLedger([entry]);
    final host = await pumpEditHost(tester, ledger);
    await _open(tester, host, entry);

    _form(host, entry).setAmount('42');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Update entry'));
    await tester.pumpAndSettle();

    expect(ledger.state.entries[entry.id]!.amount, Decimal.parse('-42'));
    expect(find.byType(AppSheet), findsNothing);
  }, timeout: uiTestTimeout);

  testWidgets('drag-down discards and reopening shows the persisted amount', (
    tester,
  ) async {
    final entry = editableEntry();
    final host = await pumpEditHost(tester, editLedger([entry]));
    await _open(tester, host, entry);

    _form(host, entry).setAmount('99');
    await tester.pumpAndSettle();
    await dismissAddSheet(tester, title: _editTitle);
    expect(find.byType(AppSheet), findsNothing);
    await _open(tester, host, entry);

    final amountField = tester.widget<EditableText>(
      find.byType(EditableText).first,
    );
    expect(amountField.controller.text, '5.00');
  }, timeout: uiTestTimeout);

  testWidgets('Delete archives the entry and the route completes', (
    tester,
  ) async {
    final entry = editableEntry();
    final ledger = editLedger([entry]);
    final host = await pumpEditHost(tester, ledger);
    await _open(tester, host, entry);

    await tester.ensureVisible(find.byKey(_deleteKey));
    await tester.tap(find.byKey(_deleteKey));
    await tester.pumpAndSettle();

    expect(ledger.state.entries, isNot(contains(entry.id)));
    expect(ledger.state.binnedEntries, contains(entry.id));
    expect(find.byType(AppSheet), findsNothing);
  }, timeout: uiTestTimeout);

  testWidgets('a system entry offers no Delete action', (tester) async {
    final opening = openingBalanceEntry();
    final host = await pumpEditHost(tester, editLedger([opening]));
    await _open(tester, host, opening);

    expect(find.byKey(_deleteKey), findsNothing);
  }, timeout: uiTestTimeout);

  testWidgets('Category opens one AppSheet picker and applies the choice', (
    tester,
  ) async {
    final entry = editableEntry();
    final host = await pumpEditHost(tester, editLedger([entry]));
    await _open(tester, host, entry);

    await tester.ensureVisible(find.text('Category'));
    await tester.tap(find.text('Category'));
    await tester.pumpAndSettle();
    expect(find.byType(AppSheet), findsNWidgets(2));
    await tester.tap(find.text('Coffee'));
    await tester.pumpAndSettle();

    expect(find.byType(AppSheet), findsOneWidget);
    expect(_state(host, entry).categoryId, editCoffee.id);
  }, timeout: uiTestTimeout);

  testWidgets('a second open while installed is ignored', (tester) async {
    final entry = editableEntry();
    final host = await pumpEditHost(tester, editLedger([entry]));

    unawaited(
      openEditEntry(context: host.context, ref: host.ref, entryId: entry.id),
    );
    unawaited(
      openEditEntry(context: host.context, ref: host.ref, entryId: entry.id),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppSheet), findsOneWidget);
  }, timeout: uiTestTimeout);

  testWidgets('saving then reopening the same entry opens a fresh form', (
    tester,
  ) async {
    final entry = editableEntry();
    final host = await pumpEditHost(tester, editLedger([entry]));
    await _open(tester, host, entry);
    await tester.tap(find.text('Update entry'));
    await tester.pumpAndSettle();
    expect(find.byType(AppSheet), findsNothing);

    await _open(tester, host, entry);

    expect(find.byType(AppSheet), findsOneWidget);
    expect(_state(host, entry).dismissed, isFalse);
  }, timeout: uiTestTimeout);
}
