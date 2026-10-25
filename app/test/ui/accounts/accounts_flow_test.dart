import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/money_navigation_provider.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/accounts/accounts_flow.dart';
import 'package:spendwise/ui/accounts/accounts_screen.dart';
import 'package:spendwise/ui/accounts/accounts_view_model.dart';
import 'package:spendwise/ui/accounts/money_navigation.dart';
import 'package:spendwise/ui/money/money_flow.dart';

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

  testWidgets('AccountOpened pushes a TransactionsFlow with a tappable back '
      'button, so a platform with no system back gesture can still return to '
      'the accounts list', (tester) async {
    final container = await pumpFlow(tester, buildLedger());

    container.read(accountsViewModelProvider.notifier).openAccount(checking.id);
    await tester.pumpAndSettle();

    expect(find.byType(AccountsScreen), findsNothing);

    final backButtonFinder = find.byTooltip('Back');
    expect(backButtonFinder, findsOneWidget);

    await tester.tap(backButtonFinder);
    await tester.pumpAndSettle();

    expect(find.byType(AccountsScreen), findsOneWidget);
  }, timeout: uiTestTimeout);

  testWidgets(
    'scoped Transactions fills Money content and Back restores Accounts state',
    (tester) async {
      final ledger = buildLedger();
      final observer = MoneyNavigatorObserver();
      final container = ProviderContainer(
        overrides: [
          ledgerProvider.overrideWithValue(ledger),
          moneyNavigatorObserverProvider.overrideWithValue(observer),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: MoneyFlow(moneyObserver: observer)),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Money'), findsOneWidget);
      expect(find.text('Budgets'), findsOneWidget);
      expect(find.text('Accounts'), findsOneWidget);
      expect(find.text('Plans'), findsOneWidget);

      container
          .read(accountsViewModelProvider.notifier)
          .toggleExpanded(checking.id);
      container
          .read(accountsViewModelProvider.notifier)
          .openAccount(checking.id);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Money'), findsNothing);
      expect(find.text('Budgets'), findsNothing);
      expect(find.text('Accounts'), findsNothing);
      expect(find.text('Plans'), findsNothing);
      expect(find.text('Main Checking'), findsOneWidget);
      expect(find.byTooltip('Back'), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Money'), findsOneWidget);
      expect(find.text('Accounts'), findsOneWidget);
      expect(find.byType(AccountsScreen), findsOneWidget);
      expect(container.read(moneySegmentProvider), MoneySegment.accounts);
      expect(
        container.read(accountsViewModelProvider).value?.expandedAccountId,
        checking.id,
      );
    },
    timeout: uiTestTimeout,
  );
}
