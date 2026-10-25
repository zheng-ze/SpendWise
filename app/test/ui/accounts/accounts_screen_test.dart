import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/accounts/accounts_screen.dart';
import 'package:spendwise/ui/accounts/accounts_view_model.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';

import '../../support/ui_test_timeout.dart';

void main() {
  Decimal dec(String value) => Decimal.parse(value);

  final checking = Account(
    id: 'a0000000-0000-0000-0000-000000000001',
    name: 'Main Checking',
    type: AccountType.checking,
    subPocketIDs: {'a0000000-0000-0000-0000-000000000002'},
  );
  final rentPocket = SubPocket(
    id: 'a0000000-0000-0000-0000-000000000002',
    name: 'Rent',
  );
  final savings = Account(
    id: 'a0000000-0000-0000-0000-000000000003',
    name: 'Piggy Bank',
    type: AccountType.savings,
  );

  Ledger buildLedger({Map<String, Entry> entries = const {}}) {
    return Ledger(
      state: LedgerState(
        moneySources: {
          checking.id: MoneySource.account(checking),
          rentPocket.id: MoneySource.pocket(rentPocket),
          savings.id: MoneySource.account(savings),
        },
        entries: entries,
      ),
    );
  }

  Future<ProviderContainer> pumpScreen(
    WidgetTester tester,
    Ledger ledger, {
    ShellLayoutMode mode = ShellLayoutMode.phone,
  }) async {
    final container = ProviderContainer(
      overrides: [
        ledgerProvider.overrideWithValue(ledger),
        shellLayoutModeProvider.overrideWithValue(mode),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AccountsScreen()),
      ),
    );
    await tester.pump();
    return container;
  }

  testWidgets(
    'expansion is single-open, opening a second collapses the first',
    (tester) async {
      final ledger = buildLedger();
      final container = await pumpScreen(tester, ledger);
      await tester.pumpAndSettle();

      expect(find.text('Rent'), findsNothing);

      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();

      expect(find.text('Rent'), findsOneWidget);
      expect(find.text('Excluding subpockets'), findsOneWidget);
      expect(
        container.read(accountsViewModelProvider).value?.selectedDetail,
        isNull,
      );

      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pumpAndSettle();

      expect(find.text('Rent'), findsNothing);
    },
    timeout: uiTestTimeout,
  );

  testWidgets('tapping the account row selects its account detail', (
    tester,
  ) async {
    final ledger = buildLedger();
    final container = await pumpScreen(tester, ledger);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Main Checking'));
    await tester.pump();

    final step = container.read(accountsViewModelProvider).value?.step;
    expect(step, isA<AccountDetailRequested>());
    expect(
      container.read(accountsViewModelProvider).value?.selectedDetail?.title,
      'Main Checking',
    );
  }, timeout: uiTestTimeout);

  testWidgets('the excluding-subpockets row emits AccountAloneOpened', (
    tester,
  ) async {
    final ledger = buildLedger();
    final container = await pumpScreen(tester, ledger);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Excluding subpockets'));
    await tester.pump();

    final step = container.read(accountsViewModelProvider).value?.step;
    expect(step, isA<AccountAloneOpened>());
    final opened = step as AccountAloneOpened;
    expect(opened.title, 'Main Checking');
    expect(opened.scopeIDs, {checking.id});
  }, timeout: uiTestTimeout);

  testWidgets('a pocket row selects the pocket detail', (tester) async {
    final ledger = buildLedger();
    final container = await pumpScreen(tester, ledger);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rent'));
    await tester.pump();

    final step = container.read(accountsViewModelProvider).value?.step;
    expect(step, isA<AccountDetailRequested>());
    expect(
      container.read(accountsViewModelProvider).value?.selectedDetail?.title,
      'Rent',
    );
  }, timeout: uiTestTimeout);

  testWidgets('open mode keeps selected account detail in Accounts', (
    tester,
  ) async {
    final container = await pumpScreen(
      tester,
      buildLedger(),
      mode: ShellLayoutMode.open,
    );
    await tester.pumpAndSettle();

    container
        .read(accountsViewModelProvider.notifier)
        .selectDetail(checking.id);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('account-detail-page')), findsNothing);
    expect(find.byKey(const ValueKey('account-detail-title')), findsOneWidget);
    expect(find.text('All balances'), findsOneWidget);
  }, timeout: uiTestTimeout);

  testWidgets('desktop detail account menu requests source editing', (
    tester,
  ) async {
    final container = await pumpScreen(
      tester,
      buildLedger(),
      mode: ShellLayoutMode.desktop,
    );
    await tester.pumpAndSettle();

    container
        .read(accountsViewModelProvider.notifier)
        .selectDetail(checking.id);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Account actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit account'));
    await tester.pump();

    expect(
      container.read(accountsViewModelProvider).value?.step,
      isA<SourceEditRequested>(),
    );
  }, timeout: uiTestTimeout);

  testWidgets('pocket detail opens its own entry scope', (tester) async {
    final container = await pumpScreen(
      tester,
      buildLedger(),
      mode: ShellLayoutMode.open,
    );
    await tester.pumpAndSettle();

    container
        .read(accountsViewModelProvider.notifier)
        .selectDetail(rentPocket.id);
    await tester.pumpAndSettle();
    await tester.tap(find.text('View entries'));
    await tester.pump();

    final step = container.read(accountsViewModelProvider).value?.step;
    expect(step, isA<PocketOpened>());
    expect((step as PocketOpened).scopeIDs, {rentPocket.id});
  }, timeout: uiTestTimeout);

  testWidgets('the delete confirmation names the account', (tester) async {
    final entry = Entry(amount: dec('10'), name: 'x', sourceID: savings.id);
    final ledger = buildLedger(entries: {entry.id: entry});
    await pumpScreen(tester, ledger);
    await tester.pumpAndSettle();

    await tester.drag(find.text('Piggy Bank'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.text('Delete Piggy Bank?'), findsOneWidget);
  }, timeout: uiTestTimeout);

  testWidgets('deleting an expanded account collapses it', (tester) async {
    final ledger = buildLedger();
    await pumpScreen(tester, ledger);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    expect(find.text('Rent'), findsOneWidget);

    await tester.drag(find.text('Main Checking'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(
      ledger.state.moneySources[checking.id]!.lifecycle,
      LifecycleState.archived,
    );
    expect(find.text('Rent'), findsNothing);
    expect(find.text('Excluding subpockets'), findsNothing);
  }, timeout: uiTestTimeout);

  testWidgets('swiping an account row archives it behind a confirmation', (
    tester,
  ) async {
    final ledger = buildLedger();
    await pumpScreen(tester, ledger);
    await tester.pumpAndSettle();

    await tester.drag(find.text('Piggy Bank'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(
      ledger.state.activeAccounts.map((a) => a.name),
      isNot(contains('Piggy Bank')),
    );
  }, timeout: uiTestTimeout);

  testWidgets('swiping a pocket row archives it behind a confirmation', (
    tester,
  ) async {
    final ledger = buildLedger();
    await pumpScreen(tester, ledger);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();

    await tester.drag(find.text('Rent'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(
      ledger.state.moneySources[rentPocket.id]!.lifecycle,
      LifecycleState.archived,
    );
  }, timeout: uiTestTimeout);
}
