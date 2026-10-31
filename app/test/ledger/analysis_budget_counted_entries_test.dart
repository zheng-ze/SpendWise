import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ledger/analysis/budgets/budget_counted_entries.dart';
import 'package:spendwise/ledger/analysis/budgets/budget_spend.dart';

void main() {
  Decimal dec(String value) => Decimal.parse(value);

  const foodID = 'a0000000-0000-0000-0000-000000000001';
  const hawkerID = 'a0000000-0000-0000-0000-000000000002';
  const transportID = 'a0000000-0000-0000-0000-000000000003';
  const month = YearMonth(2026, 7);
  DateTime day(int d) => DateTime.utc(2026, 7, d);

  TransactionCategory category(String id, {String? parentID}) =>
      TransactionCategory(
        id: id,
        name: id,
        kind: CategoryKind.expense,
        colorHex: '#FF0000',
        includeInAnalysis: true,
        parentID: parentID,
        symbol: 'restaurant',
      );

  Account account(String id, {bool flagged = false}) => Account(
    id: id,
    name: id,
    type: AccountType.savings,
    incomingTransfersAsExpenses: flagged,
  );

  const plainID = 'b0000000-0000-0000-0000-000000000001';
  const flaggedID = 'b0000000-0000-0000-0000-000000000002';
  const otherFlaggedID = 'b0000000-0000-0000-0000-000000000003';

  Budget budget(String? categoryID) =>
      Budget(categoryID: categoryID, limit: dec('100'));

  Entry expense(String name, String amount, {String? categoryID, int d = 5}) =>
      Entry(
        amount: dec(amount),
        name: name,
        sourceID: plainID,
        categoryID: categoryID,
        date: day(d),
      );

  Entry transfer(String name, {String from = plainID, String to = flaggedID}) =>
      Entry(
        amount: dec('40'),
        name: name,
        sourceID: from,
        destinationID: to,
        date: day(5),
      );

  LedgerState ledgerOf(List<Entry> entries) => LedgerState(
    moneySources: {
      plainID: MoneySource.account(account(plainID)),
      flaggedID: MoneySource.account(account(flaggedID, flagged: true)),
      otherFlaggedID: MoneySource.account(
        account(otherFlaggedID, flagged: true),
      ),
    },
    categories: {
      foodID: category(foodID),
      hawkerID: category(hawkerID, parentID: foodID),
      transportID: category(transportID),
    },
    entries: {for (final entry in entries) entry.id: entry},
  );

  List<String> names(List<BudgetCountedEntry> counted) =>
      [for (final row in counted) row.entry.name]..sort();

  test(
    'a destination-flagged transfer counts only toward an unscoped budget',
    () {
      final state = ledgerOf([transfer('into flagged')]);

      expect(names(budgetCountedEntries(budget(null), month, state)), [
        'into flagged',
      ]);
      expect(budgetCountedEntries(budget(foodID), month, state), isEmpty);
    },
  );

  test('a source-only flagged transfer is absent because it yields income', () {
    final state = ledgerOf([
      transfer('out of flagged', from: flaggedID, to: plainID),
    ]);

    expect(budgetCountedEntries(budget(null), month, state), isEmpty);
  });

  test(
    'a transfer between two flagged accounts appears once at its amount',
    () {
      final state = ledgerOf([transfer('both', from: otherFlaggedID)]);

      final counted = budgetCountedEntries(budget(null), month, state);

      expect(names(counted), ['both']);
      expect(counted.single.amount, dec('40'));
    },
  );

  test('a parent scope counts direct and child expenses, a child scope only itself', () {
    final state = ledgerOf([
      expense('direct', '-3', categoryID: foodID),
      expense('child', '-4', categoryID: hawkerID),
      expense('other', '-5', categoryID: transportID),
    ]);

    expect(names(budgetCountedEntries(budget(foodID), month, state)), [
      'child',
      'direct',
    ]);
    expect(names(budgetCountedEntries(budget(hawkerID), month, state)), [
      'child',
    ]);
  });

  test('entries outside the half-open month, excluded from analysis or income never count', () {
    final state = ledgerOf([
      expense('in', '-3'),
      expense('last day', '-3', d: 31),
      Entry(
        amount: dec('-9'),
        name: 'june',
        sourceID: plainID,
        date: DateTime.utc(2026, 6, 30),
      ),
      Entry(
        amount: dec('-9'),
        name: 'august',
        sourceID: plainID,
        date: DateTime.utc(2026, 8, 1),
      ),
      Entry(
        amount: dec('-9'),
        name: 'hidden',
        sourceID: plainID,
        date: day(2),
        includeInAnalysis: false,
      ),
      Entry(amount: dec('50'), name: 'salary', sourceID: plainID, date: day(2)),
    ]);

    expect(names(budgetCountedEntries(budget(null), month, state)), [
      'in',
      'last day',
    ]);
  });

  test('the folded row total equals budgetSpend over the classified items', () {
    final state = ledgerOf([
      expense('a', '-3'),
      expense('b', '-4.5', categoryID: hawkerID),
      transfer('into flagged'),
      transfer('both', from: otherFlaggedID),
    ]);
    final items = Accounting.analysisItems(state);
    final unscoped = budget(null);

    final counted = budgetCountedEntries(unscoped, month, state);

    expect(
      budgetCountedTotal(counted),
      budgetSpend(unscoped, month, items, state),
    );
    expect(budgetCountedTotal(counted), dec('87.5'));
  });
}
