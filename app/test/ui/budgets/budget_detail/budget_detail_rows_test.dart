import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/budgets/budget_detail/budget_detail_screen.dart';

import '../../../support/ui_test_timeout.dart';

void main() {
  Decimal dec(String value) => Decimal.parse(value);

  final today = DateTime.now();
  DateTime day(int d) => DateTime.utc(today.year, today.month, d);

  final checking = Account(
    id: 'a0000000-0000-0000-0000-000000000010',
    name: 'Checking',
    type: AccountType.checking,
  );
  final savings = Account(
    id: 'a0000000-0000-0000-0000-000000000011',
    name: 'Savings',
    type: AccountType.savings,
    incomingTransfersAsExpenses: true,
  );
  final overall = Budget(
    id: 'b1',
    categoryID: null,
    limitEvents: [
      LimitEvent(
        effectiveFromMonth: null,
        value: dec('100'),
        kind: LimitEventKind.defaultLimit,
      ),
    ],
    createdAtMonth: const YearMonth(2026, 1),
  );

  Future<void> pumpDetail(WidgetTester tester, List<Entry> entries) {
    final ledger = Ledger(
      state: LedgerState(
        moneySources: {
          checking.id: MoneySource.account(checking),
          savings.id: MoneySource.account(savings),
        },
        entries: {for (final entry in entries) entry.id: entry},
        budgets: {overall.id: overall},
      ),
    );
    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          ledgerProvider.overrideWithValue(ledger),
          analysisComputeRunnerProvider.overrideWithValue(syncComputeRunner),
        ],
        child: MaterialApp(home: BudgetDetailScreen(budgetID: overall.id)),
      ),
    );
  }

  testWidgets(
    'an unscoped budget lists the eligible transfer its total counts and the '
    'day total matches the headline',
    (tester) async {
      final lunch = Entry(
        amount: dec('-10'),
        name: 'Lunch',
        sourceID: checking.id,
        date: day(1),
      );
      final topUp = Entry(
        amount: dec('40'),
        name: 'Top up',
        sourceID: checking.id,
        destinationID: savings.id,
        date: day(1),
      );

      await pumpDetail(tester, [lunch, topUp]);
      await tester.pumpAndSettle();

      expect(find.textContaining('S\$50.00 of S\$100.00'), findsOneWidget);
      expect(find.text('Lunch'), findsOneWidget);
      expect(find.text('Top up'), findsOneWidget);
      expect(find.text('-10.00'), findsOneWidget);
      expect(find.text('40.00'), findsOneWidget);
      expect(find.text('-50.00'), findsOneWidget);
    },
    timeout: uiTestTimeout,
  );

  testWidgets(
    'a transfer between two flagged accounts appears once with its counted '
    'expense amount',
    (tester) async {
      final flaggedChecking = Account(
        id: checking.id,
        name: 'Checking',
        type: AccountType.savings,
        incomingTransfersAsExpenses: true,
      );
      final move = Entry(
        amount: dec('25'),
        name: 'Shuffle',
        sourceID: flaggedChecking.id,
        destinationID: savings.id,
        date: day(1),
      );
      final ledger = Ledger(
        state: LedgerState(
          moneySources: {
            flaggedChecking.id: MoneySource.account(flaggedChecking),
            savings.id: MoneySource.account(savings),
          },
          entries: {move.id: move},
          budgets: {overall.id: overall},
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ledgerProvider.overrideWithValue(ledger),
            analysisComputeRunnerProvider.overrideWithValue(syncComputeRunner),
          ],
          child: MaterialApp(home: BudgetDetailScreen(budgetID: overall.id)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('S\$25.00 of S\$100.00'), findsOneWidget);
      expect(find.text('Shuffle'), findsOneWidget);
      expect(find.text('-25.00'), findsOneWidget);
    },
    timeout: uiTestTimeout,
  );
}
