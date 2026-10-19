import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/accounts/account_form/account_form.dart';
import 'package:spendwise/ui/accounts/accounts_flow.dart';
import 'package:spendwise/ui/accounts/accounts_screen.dart';
import 'package:spendwise/ui/accounts/accounts_view_model.dart';
import 'package:spendwise/ui/accounts/source_edit/source_edit_form.dart';
import 'package:spendwise/ui/transactions/transactions_flow.dart';

import '../../support/ui_test_timeout.dart';

void main() {
  final checking = Account(
    id: 'a0000000-0000-0000-0000-000000000001',
    name: 'Main Checking',
    type: AccountType.checking,
  );

  Ledger buildLedger() {
    return Ledger(
      state: LedgerState(
        moneySources: {checking.id: MoneySource.account(checking)},
      ),
    );
  }

  Future<ProviderContainer> pumpFlow(WidgetTester tester, Ledger ledger) async {
    final container = ProviderContainer(
      overrides: [ledgerProvider.overrideWithValue(ledger)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AccountsFlow()),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('AccountFormRequested opens the account form sheet', (
    tester,
  ) async {
    final container = await pumpFlow(tester, buildLedger());

    container.read(accountsViewModelProvider.notifier).requestNewAccount();
    await tester.pumpAndSettle();

    expect(find.byType(AccountForm), findsOneWidget);
    expect(container.read(accountsViewModelProvider).value?.step, isNull);
  }, timeout: uiTestTimeout);

  testWidgets('SourceEditRequested opens the source edit sheet for that '
      'holder', (tester) async {
    final container = await pumpFlow(tester, buildLedger());

    container
        .read(accountsViewModelProvider.notifier)
        .requestSourceEdit(checking.id);
    await tester.pumpAndSettle();

    final form = tester.widget<SourceEditForm>(find.byType(SourceEditForm));
    expect(form.holderID, checking.id);
  }, timeout: uiTestTimeout);

  testWidgets('AccountOpened pushes a TransactionsFlow scoped to the '
      'account and its pockets', (tester) async {
    final container = await pumpFlow(tester, buildLedger());

    container.read(accountsViewModelProvider.notifier).openAccount(checking.id);
    await tester.pumpAndSettle();

    final pushed = tester.widget<TransactionsFlow>(
      find.byType(TransactionsFlow),
    );
    expect(pushed.initialScope?.title, 'Main Checking');
    expect(pushed.initialScope?.scopeIDs, {checking.id});
  }, timeout: uiTestTimeout);

  testWidgets('AccountOpened pushes a TransactionsFlow whose AppBar shows a '
      'tappable back button, so a platform with no system back gesture can '
      'still return to the accounts list', (tester) async {
    final container = await pumpFlow(tester, buildLedger());

    container.read(accountsViewModelProvider.notifier).openAccount(checking.id);
    await tester.pumpAndSettle();

    expect(find.byType(AccountsScreen), findsNothing);

    final backButtonFinder = find.descendant(
      of: find.byType(AppBar),
      matching: find.byTooltip('Back'),
    );
    expect(backButtonFinder, findsOneWidget);

    await tester.tap(backButtonFinder);
    await tester.pumpAndSettle();

    expect(find.byType(AccountsScreen), findsOneWidget);
  }, timeout: uiTestTimeout);

  testWidgets('back navigation while the account form sheet is open pops '
      "the sheet, not the Flow's own screen", (tester) async {
    final container = await pumpFlow(tester, buildLedger());
    expect(find.byType(AccountForm), findsNothing);

    container.read(accountsViewModelProvider.notifier).requestNewAccount();
    await tester.pumpAndSettle();
    expect(find.byType(AccountForm), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(AccountForm), findsNothing);
    expect(find.byType(AccountsFlow), findsOneWidget);
  }, timeout: uiTestTimeout);
}
