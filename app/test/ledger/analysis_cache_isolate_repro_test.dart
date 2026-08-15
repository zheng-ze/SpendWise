import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ledger/analysis_cache.dart';

void main() {
  test('isolateRunnerCompletesFor21RealisticEntries', () async {
    final state = LedgerState();

    final account = Account(name: 'wallet', type: AccountType.savings);
    state.addAccount(account);

    final pocket = SubPocket(name: 'sub');
    state.addPocket(pocket, account.id);

    final expenseCategory = TransactionCategory(
      name: 'food',
      kind: CategoryKind.expense,
      colorHex: '#00FF00',
      includeInAnalysis: true,
      parentID: null,
      symbol: 'tag',
    );
    state.addCategory(expenseCategory);

    final incomeCategory = TransactionCategory(
      name: 'salary',
      kind: CategoryKind.income,
      colorHex: '#0000FF',
      includeInAnalysis: true,
      parentID: null,
      symbol: 'tag',
    );
    state.addCategory(incomeCategory);

    for (var i = 0; i < 20; i++) {
      final isExpense = i.isEven;
      state.addEntry(
        Entry(
          amount: Decimal.parse(isExpense ? '-12.50' : '30.00'),
          name: 'entry $i',
          sourceID: account.id,
          categoryID: isExpense ? expenseCategory.id : incomeCategory.id,
          date: DateTime.utc(2026, (i % 12) + 1, 15),
        ),
      );
    }

    state.addEntry(
      Entry(
        amount: Decimal.parse('5.00'),
        name: 'transfer',
        sourceID: account.id,
        destinationID: pocket.id,
        date: DateTime.utc(2026, 8, 1),
      ),
    );

    final result = await isolateComputeRunner(
      state,
    ).timeout(const Duration(seconds: 10));

    expect(result, isNotEmpty);
  });
}
