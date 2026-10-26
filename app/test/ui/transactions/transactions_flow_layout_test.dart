import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/common/lists/responsive_summary_card.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/shell/app_shell.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/transactions/daily_list/transactions_summary.dart';
import 'package:spendwise/ui/transactions/entry/new_entry_presenter.dart';
import 'package:spendwise/ui/transactions/transactions_flow.dart';

void main() {
  testWidgets(
    'History uses a single-column page while Add occupies the right pane',
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
      container.read(newEntryPresentationProvider.notifier).state =
          NewEntryPresentation.presented;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: AppShell(
              bodies: {
                ShellDestination.history: (_) => const TransactionsFlow(),
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final summary = tester.widget<TransactionsSummary>(
        find.byType(TransactionsSummary),
      );
      final card = tester.widget<ResponsiveSummaryCard>(
        find.byType(ResponsiveSummaryCard),
      );
      expect(summary.wideComposition, isFalse);
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
      expect(card.wideComposition, isFalse);
      expect(find.text('Net'), findsOneWidget);
      expect(find.text('Spent'), findsOneWidget);
      expect(find.text('Income'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
