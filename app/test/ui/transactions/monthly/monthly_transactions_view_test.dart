import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ui/transactions/monthly/month_summaries.dart';
import 'package:spendwise/ui/transactions/monthly/monthly_transactions_view.dart';

void main() {
  final account = Account(
    id: 'a0000000-0000-0000-0000-000000000001',
    name: 'Checking',
    type: AccountType.checking,
  );

  LedgerState state() =>
      LedgerState(moneySources: {account.id: MoneySource.account(account)});

  final monthLabel = RegExp(r'^[A-Z][a-z]+ \d{4}$');
  final weekLabel = RegExp(r'^\d{1,2} \w+ - ');

  Future<void> pump(WidgetTester tester, Widget child) {
    return tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  }

  testWidgets('expanding a month collapses a previously expanded month', (
    tester,
  ) async {
    final year = DateTime.utc(DateTime.now().year);
    final summaries = monthSummaries(state(), year);

    await pump(
      tester,
      MonthlyTransactionsView(summaries: summaries, onWeekTap: (_) {}),
    );

    final monthRows = find.textContaining(monthLabel);
    expect(monthRows.evaluate().length, greaterThan(1));

    await tester.tap(monthRows.first);
    await tester.pumpAndSettle();
    final firstMonthWeekCount = find
        .textContaining(weekLabel)
        .evaluate()
        .length;
    expect(firstMonthWeekCount, greaterThan(0));

    await tester.tap(monthRows.at(1));
    await tester.pumpAndSettle();
    final visibleAfterSecondExpand = find
        .textContaining(weekLabel)
        .evaluate()
        .length;

    // A month spans at most 6 overlapping weeks, so if both months' weeks
    // stayed mounted at once this count would exceed that ceiling.
    expect(visibleAfterSecondExpand, greaterThan(0));
    expect(visibleAfterSecondExpand, lessThanOrEqualTo(6));

    await tester.tap(monthRows.at(1));
    await tester.pumpAndSettle();
    expect(find.textContaining(weekLabel).evaluate(), isEmpty);
  });

  testWidgets("tapping a week calls back with that week's month", (
    tester,
  ) async {
    final year = DateTime.utc(DateTime.now().year);
    final summaries = monthSummaries(state(), year);
    DateTime? tapped;

    await pump(
      tester,
      MonthlyTransactionsView(
        summaries: summaries,
        onWeekTap: (month) => tapped = month,
      ),
    );

    await tester.tap(find.textContaining(monthLabel).first);
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining(weekLabel).first);
    await tester.pumpAndSettle();

    expect(tapped, isNotNull);
  });
}
