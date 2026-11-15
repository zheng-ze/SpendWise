import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ledger/ledger.dart';

import 'analysis_pace_fixture.dart';

final _octoberStart = DateTime.utc(2026, 10, 1);

Decimal _total(Iterable<PaceRow> rows, String categoryKey) {
  return rows
      .where((row) => row.categoryKey == categoryKey)
      .fold(Decimal.zero, (sum, row) => sum + Decimal.parse(row.amount));
}

Iterable<PaceRow> _history() {
  return paceRows().where(
    (row) =>
        !row.date.isBefore(paceFirstRecordMonth) &&
        row.date.isBefore(_octoberStart),
  );
}

Iterable<PaceRow> _octoberThroughToday() {
  return paceRows().where(
    (row) => !row.date.isBefore(_octoberStart) && !row.date.isAfter(paceToday),
  );
}

Decimal _sum(Iterable<AnalysisItem> items) {
  return items.fold(Decimal.zero, (sum, item) => sum + item.amount);
}

List<AnalysisItem> _ledgerItems() {
  final ledger = Ledger();
  addPaceHistory(ledger);
  return Accounting.analysisItems(ledger.state);
}

void main() {
  test('history totals per category over Dec 2025 to Sep 2026', () {
    final rows = _history();

    expect(_total(rows, paceDining), Decimal.parse('4032.80'));
    expect(_total(rows, paceGroceries), Decimal.parse('3040.00'));
    expect(_total(rows, paceTransport), Decimal.parse('1340.40'));
  });

  test('October spend through 3 Oct per category', () {
    final rows = _octoberThroughToday();

    expect(_total(rows, paceDining), Decimal.parse('83.90'));
    expect(_total(rows, paceGroceries), Decimal.parse('73.50'));
    expect(_total(rows, paceTransport), Decimal.parse('10.00'));
  });

  test('the committed 15 Oct Groceries row lies after today', () {
    final future = paceRows().where((row) => row.date.isAfter(paceToday));

    expect(future.map((row) => row.amount), ['60.00']);
    expect(future.single.categoryKey, paceGroceries);
  });

  test('ledger-built items agree with paceItems on count and sum', () {
    final fromLedger = _ledgerItems();
    final direct = paceItems();

    expect(fromLedger.length, direct.length);
    expect(_sum(fromLedger), _sum(direct));
  });

  test('accounting-classified items match paceItems', () {
    expect(_ledgerItems(), unorderedEquals(paceItems()));
  });
}
