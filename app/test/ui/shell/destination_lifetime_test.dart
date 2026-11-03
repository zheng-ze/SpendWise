import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/format/date_format.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/transactions/transactions_flow.dart';
import 'package:spendwise/ui/transactions/trends_detail_action.dart';

import '../../support/shell_sheet_harness.dart';
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
}
