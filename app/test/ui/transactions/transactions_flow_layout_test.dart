import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/common/lists/responsive_summary_card.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/shell/app_shell.dart';
import 'package:spendwise/ui/shell/shell_pane_host.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/shell/shell_sheet_occupancy.dart';
import 'package:spendwise/ui/transactions/daily_list/transactions_summary.dart';
import 'package:spendwise/ui/transactions/transactions_flow.dart';

import '../../support/shell_sheet_harness.dart';
import '../../support/ui_test_timeout.dart';

const _historySize = Size(640, 800);

void main() {
  testWidgets(
    'History retains its Flow and Navigator through sheet occupancy',
    (tester) async {
      useShellWindow(
        tester,
        _historySize,
        padding: const FakeViewPadding(left: 54, right: 54),
      );
      final container = ProviderContainer(
        overrides: [
          ledgerProvider.overrideWithValue(Ledger(state: LedgerState())),
          shellLayoutModeProvider.overrideWithValue(ShellLayoutMode.open),
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
      final flowFinder = find.byType(TransactionsFlow);
      final flow = tester.state(flowFinder);
      final navigatorFinder = find.descendant(
        of: flowFinder,
        matching: find.byType(Navigator),
      );
      final navigator = tester.state(navigatorFinder);
      final context = tester.element(flowFinder);
      final sheet = pushShellSheet(
        context,
        builder: (_) =>
            const AppSheet(header: Text('Form'), body: Text('Draft')),
      );
      await tester.pumpAndSettle();
      expect(ShellPaneScope.of(context).sheetPresented, isTrue);
      final shellRoute = ModalRoute.of(tester.element(find.byType(AppShell)));
      expect(
        ProviderScope.containerOf(context)
            .read(shellSheetOccupancyProvider)
            .isCovered(shellRoute),
        isTrue,
      );
      expect(tester.state(flowFinder), same(flow));
      expect(tester.state(navigatorFinder), same(navigator));
      final summary = tester.widget<TransactionsSummary>(
        find.byType(TransactionsSummary),
      );
      final card = tester.widget<ResponsiveSummaryCard>(
        find.byType(ResponsiveSummaryCard),
      );
      expect(summary.wideComposition, isFalse);
      expect(card.wideComposition, isFalse);
      expect(card.metrics.map((metric) => metric.label).toList(), [
        'Net',
        'Spent',
        'Income',
      ]);
      expect(card.metrics.map((metric) => metric.kind).toList(), [
        null,
        AmountKind.expense,
        AmountKind.income,
      ]);
      expect(card.metrics.first.emphasis, SummaryMetricEmphasis.primary);
      sheet.navigator!.pop();
      await tester.pumpAndSettle();
      await sheet.completed.timeout(sheetCompletionTimeout);
      expect(ShellPaneScope.of(context).sheetPresented, isFalse);
      expect(tester.state(flowFinder), same(flow));
      expect(tester.state(navigatorFinder), same(navigator));
      expect(tester.takeException(), isNull);
    },
    timeout: uiTestTimeout,
  );
}
