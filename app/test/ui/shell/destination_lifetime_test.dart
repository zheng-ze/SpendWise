import 'package:domain/domain.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/format/date_format.dart';
import 'package:spendwise/ui/overview/overview_constants.dart';
import 'package:spendwise/ui/overview/overview_flow.dart';
import 'package:spendwise/ui/settings/category/category_list_screen.dart';
import 'package:spendwise/ui/settings/settings_flow.dart';
import 'package:spendwise/ui/settings/settings_root_screen.dart';
import 'package:spendwise/ui/stats/trends_flow.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/transactions/transactions_flow.dart';
import 'package:spendwise/ui/transactions/trends_detail_action.dart';

import '../../support/shell_sheet_harness.dart';
import '../overview/overview_fixture.dart';
import '../../support/ui_test_timeout.dart';

void main() {
  testWidgets(
    'History keeps its previous month after opening Trends and going Back',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          ledgerProvider.overrideWithValue(Ledger(state: LedgerState())),
        ],
      );
      addTearDown(container.dispose);
      container.read(selectedDestinationProvider.notifier).state =
          ShellDestination.history;
      await pumpShellApp(
        tester,
        container,
        bodies: {ShellDestination.history: (_) => const TransactionsFlow()},
      );

      await tester.tap(find.byTooltip('Previous month'));
      await tester.pumpAndSettle();
      final now = DateTime.now();
      final previousMonth = formatMonthLabel(
        DateTime.utc(now.year, now.month - 1),
      );
      expect(find.text(previousMonth), findsOneWidget);

      await tester.tap(find.text(trendsDetailActionLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.text(previousMonth), findsOneWidget);
    },
    timeout: uiTestTimeout,
  );

  testWidgets(
    'Overview View History opens History at the current month without Trends',
    (tester) async {
      final ledger = Ledger(state: emptyState());
      final container = overviewContainer(ledger);
      await pumpShellApp(
        tester,
        container,
        bodies: {
          ShellDestination.overview: (_) => OverviewFlow(
            onHistorySelected: () =>
                container.read(selectedDestinationProvider.notifier).state =
                    ShellDestination.history,
          ),
          ShellDestination.history: (_) => const TransactionsFlow(),
        },
      );
      await tester.runAsync(() => settleAnalysis(container, ledger));
      container.read(selectedDestinationProvider.notifier).state =
          ShellDestination.history;
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Previous month'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(trendsDetailActionLabel));
      await tester.pumpAndSettle();
      expect(find.byType(TrendsFlow), findsOneWidget);

      container.read(selectedDestinationProvider.notifier).state =
          ShellDestination.overview;
      await tester.pumpAndSettle();
      await tester.tap(find.text(overviewHistoryLink));
      await tester.pumpAndSettle();

      final now = DateTime.now();
      final currentMonth = formatMonthLabel(DateTime.utc(now.year, now.month));
      expect(find.text(currentMonth), findsOneWidget);
      expect(find.byType(TrendsFlow), findsNothing);
    },
    timeout: uiTestTimeout,
  );

  testWidgets('Settings returns to its root after leaving it from Categories', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        ledgerProvider.overrideWithValue(Ledger(state: LedgerState())),
      ],
    );
    addTearDown(container.dispose);
    container.read(selectedDestinationProvider.notifier).state =
        ShellDestination.settings;
    await pumpShellApp(
      tester,
      container,
      bodies: {
        ShellDestination.history: (_) => const SizedBox.shrink(),
        ShellDestination.settings: (_) => const SettingsFlow(),
      },
    );
    await tester.tap(find.text('Categories'));
    await tester.pumpAndSettle();
    expect(find.byType(CategoryListScreen), findsOneWidget);

    container.read(selectedDestinationProvider.notifier).state =
        ShellDestination.history;
    await tester.pumpAndSettle();
    expect(find.byType(SettingsFlow), findsNothing);
    container.read(selectedDestinationProvider.notifier).state =
        ShellDestination.settings;
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.byType(CategoryListScreen), findsNothing);
  }, timeout: uiTestTimeout);
}
