import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ui/stats/helpers/slices.dart';
import 'package:spendwise/ui/stats/helpers/stats_window.dart';
import 'package:spendwise/ui/transactions/monthly/month_summaries.dart';

void main() {
  Decimal dec(String value) => Decimal.parse(value);
  DateTime day(int year, [int month = 1, int d = 1]) =>
      DateTime.utc(year, month, d);

  final account = Account(
    id: 'a0000000-0000-0000-0000-000000000001',
    name: 'Checking',
    type: AccountType.checking,
  );
  final flaggedSavings = Account(
    id: 'a0000000-0000-0000-0000-000000000002',
    name: 'Savings',
    type: AccountType.savings,
    incomingTransfersAsExpenses: true,
  );

  Decimal statsExpenseTotal(LedgerState state, DateTime month) {
    final items = Accounting.analysisItems(state);
    final categorySlices = slices(
      items,
      CategoryKind.expense,
      monthWindow(month),
      state,
    );
    return categorySlices.fold(
      Decimal.zero,
      (sum, slice) => sum + slice.amount,
    );
  }

  test('a treat-as-expense transfer produces the same month expense total on '
      'the Transactions screen and the Stats screen', () {
    final entries = [
      Entry(
        amount: dec('60'),
        name: 'salary',
        sourceID: account.id,
        date: day(2026, 7, 3),
      ),
      Entry(
        amount: dec('-25'),
        name: 'groceries',
        sourceID: account.id,
        date: day(2026, 7, 4),
      ),
      Entry(
        amount: dec('75'),
        name: 'move to savings',
        sourceID: account.id,
        destinationID: flaggedSavings.id,
        date: day(2026, 7, 8),
      ),
    ];
    final state = LedgerState(
      moneySources: {
        account.id: MoneySource.account(account),
        flaggedSavings.id: MoneySource.account(flaggedSavings),
      },
      entries: {for (final entry in entries) entry.id: entry},
    );

    final months = monthSummaries(state, day(2026), now: day(2026, 7, 15));
    final july = months.firstWhere((m) => m.month == day(2026, 7, 1));

    final statsTotal = statsExpenseTotal(state, day(2026, 7, 1));

    expect(july.expenses, dec('100'));
    expect(statsTotal, dec('100'));
    expect(july.expenses, statsTotal);
  });
}
