import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/transactions/transactions_flow.dart';

import '../../support/edit_entry_harness.dart';
import '../../support/pump_app.dart';
import '../../support/row_tap.dart';
import '../../support/ui_test_timeout.dart';

const _scopeTitle = 'Checking';
const _editTitle = 'Edit entry';

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

void main() {
  testWidgets('tapping a register row installs an Edit entry sheet', (
    tester,
  ) async {
    final entry = editableEntry();
    await _pumpScopedFlow(tester, entry);

    await tapRow(tester, find.text(entry.name));

    expect(find.byType(AppSheet), findsOneWidget);
    expect(find.text(_editTitle), findsOneWidget);
  }, timeout: uiTestTimeout);
}
