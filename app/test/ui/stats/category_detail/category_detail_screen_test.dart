import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ledger/analysis/breakdowns/analysis_category_scope.dart';
import 'package:spendwise/ledger/analysis/breakdowns/scoped_trend.dart';
import 'package:spendwise/ledger/analysis/category_detail/category_detail.dart';
import 'package:spendwise/ledger/ledger.dart';

void main() {
  test(
    'entries excluded directly or through their category stay out of the list',
    () {
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
      final result = categoryDetailPeriod(
        state: ledger.state,
        items: Accounting.analysisItems(ledger.state),
        mainID: foodID,
        kind: CategoryKind.expense,
        scope: const AllCategoryScope(),
        period: DateTime.utc(2026, 10),
        mode: AnalysisPeriodMode.month,
      );

      expect(result.entryIDs, [includedEntry.id]);
      expect(result.entryIDs, isNot(contains(excludedEntry.id)));
      expect(result.entryIDs, isNot(contains(entryInExcludedCategory.id)));
      expect(result.totals.scopeTotal, Decimal.fromInt(12));
    },
  );
}
