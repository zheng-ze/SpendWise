import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/stats/category_detail/category_detail_screen.dart';
import 'package:spendwise/ui/stats/category_detail/category_detail_view_model.dart';

import '../../../support/ui_test_timeout.dart';

void main() {
  testWidgets(
    'entries excluded directly or through their category stay out of the list',
    (tester) async {
      const accountID = 'a0000000-0000-0000-0000-000000000010';
      const foodID = 'a0000000-0000-0000-0000-000000000001';
      const excludedID = 'a0000000-0000-0000-0000-000000000099';
      final account = Account(
        id: accountID,
        name: 'Checking',
        type: AccountType.checking,
      );
      final food = TransactionCategory(
        id: foodID,
        name: 'Food',
        kind: CategoryKind.expense,
        colorHex: '#00AA00',
        includeInAnalysis: true,
        parentID: null,
        symbol: 'restaurant',
      );
      final excludedCategory = TransactionCategory(
        id: excludedID,
        name: 'Excluded category',
        kind: CategoryKind.expense,
        colorHex: '#AA00AA',
        includeInAnalysis: false,
        parentID: foodID,
        symbol: 'block',
      );
      final day = DateTime.utc(2026, 10, 1);
      final excludedEntry = Entry(
        amount: Decimal.fromInt(-7),
        name: 'Excluded entry',
        sourceID: accountID,
        categoryID: foodID,
        date: day,
        includeInAnalysis: false,
      );
      final entryInExcludedCategory = Entry(
        amount: Decimal.fromInt(-9),
        name: 'Entry in excluded category',
        sourceID: accountID,
        categoryID: excludedID,
        date: day,
      );
      final includedEntry = Entry(
        amount: Decimal.fromInt(-12),
        name: 'Included entry',
        sourceID: accountID,
        categoryID: foodID,
        date: day,
      );
      final ledger = Ledger(
        state: LedgerState(
          moneySources: {accountID: MoneySource.account(account)},
          categories: {foodID: food, excludedID: excludedCategory},
          entries: {
            excludedEntry.id: excludedEntry,
            entryInExcludedCategory.id: entryInExcludedCategory,
            includedEntry.id: includedEntry,
          },
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ledgerProvider.overrideWithValue(ledger),
            analysisComputeRunnerProvider.overrideWithValue(syncComputeRunner),
          ],
          child: MaterialApp(
            home: CategoryDetailScreen(
              args: CategoryDetailArgs(
                mainID: foodID,
                kind: CategoryKind.expense,
                isYearRange: false,
                initialDate: DateTime.utc(2026, 10),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Excluded entry', skipOffstage: false), findsNothing);
      expect(find.text('Included entry', skipOffstage: false), findsOneWidget);
      expect(
        find.text('Entry in excluded category', skipOffstage: false),
        findsNothing,
      );
    },
    timeout: uiTestTimeout,
  );
}
