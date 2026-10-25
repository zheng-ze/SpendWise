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
import 'package:spendwise/ui/common/inputs/segmented_control.dart';
import 'package:spendwise/ui/common/lists/summary_band.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/money/money_flow.dart';
import 'package:spendwise/ui/shell/app_shell.dart';
import 'package:spendwise/ui/shell/open_rail.dart';
import 'package:spendwise/ui/shell/shell_binding.dart';
import 'package:spendwise/ui/shell/shell_pane_host.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';

import '../../support/ui_test_timeout.dart';

void main() {
  final checking = Account(
    id: 'a0000000-0000-0000-0000-000000000001',
    name: 'Main Checking',
    type: AccountType.checking,
  );
  final card = Account(
    id: 'a0000000-0000-0000-0000-000000000002',
    name: 'Travel Card',
    type: AccountType.card,
  );

  Ledger buildLedger() {
    return Ledger(
      state: LedgerState(
        moneySources: {
          checking.id: MoneySource.account(checking),
          card.id: MoneySource.account(card),
        },
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

  testWidgets(
    'scoped Transactions route survives Add presentation changes and Back',
    (tester) async {
      tester.view.physicalSize = const Size(1024, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final observer = MoneyNavigatorObserver();
      late ProviderContainer container;
      container = ProviderContainer(
        overrides: [
          ledgerProvider.overrideWithValue(buildLedger()),
          shellLayoutModeProvider.overrideWithValue(ShellLayoutMode.open),
          moneyNavigatorObserverProvider.overrideWithValue(observer),
        ],
      );
      addTearDown(container.dispose);
      container.read(selectedDestinationProvider.notifier).state =
          ShellDestination.money;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: ShellLayoutModeScope(
            mode: ShellLayoutMode.open,
            child: MaterialApp(
              home: AppShell(
                moneySourceId: container.read(activeMoneySourceProvider),
                bodies: {
                  ShellDestination.money: (_) =>
                      MoneyFlow(moneyObserver: observer),
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('Main Checking'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Main Checking'), findsOneWidget);
      expect(observer.sourceId, checking.id);

      await tester.tap(find.text('Add'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(AppSheet), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byKey(openRailKey),
          matching: find.text('History'),
        ),
        warnIfMissed: false,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(AppSheet), findsNothing);
      expect(find.text('Main Checking'), findsOneWidget);
      expect(observer.sourceId, checking.id);

      await tester.tap(find.byTooltip('Back'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(AccountsScreen), findsOneWidget);
    },
    timeout: uiTestTimeout,
  );

  testWidgets('account forms constrain and compact the open Money pane', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(640, 800);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(left: 54, right: 54);
    addTearDown(tester.view.reset);
    final observer = MoneyNavigatorObserver();
    final container = ProviderContainer(
      overrides: [
        ledgerProvider.overrideWithValue(buildLedger()),
        shellLayoutModeProvider.overrideWithValue(ShellLayoutMode.open),
        moneyNavigatorObserverProvider.overrideWithValue(observer),
      ],
    );
    addTearDown(container.dispose);
    container.read(selectedDestinationProvider.notifier).state =
        ShellDestination.money;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: ShellLayoutModeScope(
          mode: ShellLayoutMode.open,
          child: MaterialApp(
            home: AppShell(
              bodies: {
                ShellDestination.money: (_) =>
                    MoneyFlow(moneyObserver: observer),
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final viewModel = container.read(accountsViewModelProvider.notifier);
    for (final request in [
      () => viewModel.requestNewAccount(),
      () => viewModel.requestSourceEdit(checking.id),
    ]) {
      request();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(container.read(accountSheetPresentedProvider), isTrue);
      expect(
        ShellPaneScope.of(tester.element(find.byType(AccountsScreen)))
            .addPresented,
        isTrue,
      );
      expect(
        tester.widget<SummaryBand>(find.byType(SummaryBand).first).compact,
        isTrue,
      );
      expect(
        tester
            .widget<SegmentedControl<MoneySegment>>(
              find.byType(SegmentedControl<MoneySegment>),
            )
            .small,
        isTrue,
      );
      expect(find.text('Money'), findsNWidgets(2));
      expect(find.text('Budgets'), findsOneWidget);
      expect(find.text('Accounts'), findsOneWidget);
      expect(find.text('Plans'), findsOneWidget);
      expect(find.text('Main Checking'), findsAtLeastNWidgets(1));
      expect(find.text('Assets'), findsOneWidget);
      expect(find.text('Owed'), findsOneWidget);
      expect(find.text('Travel Card'), findsOneWidget);
      expect(find.textContaining('Payable'), findsOneWidget);
      expect(find.textContaining('Outstanding'), findsOneWidget);

      expect(container.read(moneySegmentProvider), MoneySegment.accounts);
      expect(tester.takeException(), isNull);

      Navigator.of(
        tester.element(find.byType(AppSheet).last),
        rootNavigator: true,
      ).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(container.read(accountSheetPresentedProvider), isFalse);
    }
  }, timeout: uiTestTimeout);
}
