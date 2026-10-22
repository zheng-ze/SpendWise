import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/stats/trends/trends_intent.dart';
import 'package:spendwise/ui/stats/trends/trends_view_model.dart';
import 'package:spendwise/ui/stats/trends_screen.dart';

import '../../support/ui_test_timeout.dart';
import 'trends_test_support.dart';

const _desktopTestSize = Size(1440, 900);
final _today = DateTime.utc(2026, 10, 3);

void main() {
  testWidgets(
    'desktop Trends keeps chart, category and mode actions connected',
    (tester) async {
      final ledger = emptyTrendsLedger();
      addTrendsEntry(ledger, '-5', DateTime.utc(2026, 7, 10));
      addTrendsEntry(ledger, '-7', DateTime.utc(2026, 10, 2));
      final harness = TrendsHarness(ledger: ledger, today: _today);

      await pumpTrendsApp(
        tester,
        harness.container,
        home: const TrendsScreen(layoutMode: ShellLayoutMode.desktop),
        size: _desktopTestSize,
      );

      await tester.tap(find.bySemanticsLabel('July 2026'));
      await tester.pumpAndSettle();
      expect(harness.intent.selected, monthSerial(DateTime.utc(2026, 7, 1)));

      await tester.tap(find.byIcon(Icons.chevron_right).last);
      await tester.pump();
      expect(harness.step, isA<TrendsCategoryDetailRequested>());

      await tester.tap(find.text('Year by year'));
      await tester.pumpAndSettle();
      expect(harness.intent.mode, TrendsMode.year);
    },
    timeout: uiTestTimeout,
  );
}
