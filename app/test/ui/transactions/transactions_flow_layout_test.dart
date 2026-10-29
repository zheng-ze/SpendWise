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
import 'package:spendwise/ui/shell/shell_binding.dart';
import 'package:spendwise/ui/shell/shell_pane_host.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/shell/shell_presentation_controller.dart';
import 'package:spendwise/ui/transactions/daily_list/transactions_summary.dart';
import 'package:spendwise/ui/transactions/transactions_flow.dart';

import '../../support/ui_test_timeout.dart';

const _completionTimeout = Duration(seconds: 5);

Future<void> _pumpHistory(
  WidgetTester tester,
  ProviderContainer container,
) async {
  final app = MaterialApp(
    builder: buildShellAppContent,
    home: AppShell(
      bodies: {ShellDestination.history: (_) => const TransactionsFlow()},
    ),
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: app),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'History retains its Flow and Navigator through sheet occupancy',
    (tester) async {
      tester.view.physicalSize = const Size(640, 800);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(left: 54, right: 54);
      addTearDown(tester.view.reset);
      final container = ProviderContainer(
        overrides: [
          ledgerProvider.overrideWithValue(Ledger(state: LedgerState())),
          shellLayoutModeProvider.overrideWithValue(ShellLayoutMode.open),
        ],
      );
      addTearDown(container.dispose);
      container.read(selectedDestinationProvider.notifier).state =
          ShellDestination.history;
      await _pumpHistory(tester, container);
      final flowFinder = find.byType(TransactionsFlow);
      final flow = tester.state(flowFinder);
      final navigatorFinder = find.descendant(
        of: flowFinder,
        matching: find.byType(Navigator),
      );
      final navigator = tester.state(navigatorFinder);
      final context = tester.element(flowFinder);
      final sheet = AppSheetRoute<void>(
        presentation: AppSheetPresentation.open,
        builder: (_) =>
            const AppSheet(header: Text('Form'), body: Text('Draft')),
      );
      Navigator.of(context, rootNavigator: true).push(sheet);
      await tester.pumpAndSettle();
      expect(ShellPaneScope.of(context).addPresented, isTrue);
      final shellRoute = ModalRoute.of(tester.element(find.byType(AppShell)));
      expect(
        ShellPresentationScope.read(context)!.isCovered(shellRoute),
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
      await sheet.completed.timeout(_completionTimeout);
      expect(ShellPaneScope.of(context).addPresented, isFalse);
      expect(tester.state(flowFinder), same(flow));
      expect(tester.state(navigatorFinder), same(navigator));
      expect(tester.takeException(), isNull);
    },
    timeout: uiTestTimeout,
  );
}
