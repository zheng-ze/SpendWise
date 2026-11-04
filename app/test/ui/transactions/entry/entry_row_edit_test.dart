import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/common/lists/flat_entry_sliver.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/transactions/daily_list/transaction_row.dart';

import '../../../support/edit_entry_harness.dart';
import '../../../support/pump_app.dart';
import '../../../support/ui_test_timeout.dart';
import '../../budgets/budget_detail/budget_detail_test_support.dart';

const _editTitle = 'Edit entry';
const _scrollStep = 200.0;

void main() {
  testWidgets('tapping an entry row in a flat sliver installs Edit entry', (
    tester,
  ) async {
    final entry = editableEntry();
    final ledger = editLedger([entry]);
    final state = ledger.state;
    final row = transactionRow(entry, state);
    await pumpApp(
      tester,
      Scaffold(
        body: CustomScrollView(
          slivers: [
            FlatEntrySliver(rows: [row], ledger: ledger, state: state),
          ],
        ),
      ),
      ledger: ledger,
    );
    addTearDown(() => closeAllSheets(tester));

    await tester.tap(find.text(entry.name));
    await tester.pumpAndSettle();

    expect(find.byType(AppSheet), findsOneWidget);
    expect(find.text(_editTitle), findsOneWidget);
  }, timeout: uiTestTimeout);

  testWidgets('tapping a counted budget row installs Edit entry', (
    tester,
  ) async {
    final lunch = Entry(
      amount: dec('-10'),
      name: 'Lunch',
      sourceID: checkingAccount.id,
      date: DateTime.utc(2026, 10, 1),
    );
    await pumpDetailScreen(
      tester,
      ledger: detailLedger(budgets: [detailBudget()], entries: [lunch]),
    );
    addTearDown(() => closeAllSheets(tester));

    await tester.scrollUntilVisible(find.text('Lunch'), _scrollStep);
    await tester.pump();
    await tester.tap(find.text('Lunch'));
    await tester.pumpAndSettle();

    expect(find.byType(AppSheet), findsOneWidget);
    expect(find.text(_editTitle), findsOneWidget);
  }, timeout: uiTestTimeout);
}
