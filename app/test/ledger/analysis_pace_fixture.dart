import 'package:domain/domain.dart';
import 'package:spendwise/ledger/ledger.dart';

import 'analysis_test_support.dart';

typedef PaceRow = ({String categoryKey, DateTime date, String amount});

final paceToday = DateTime.utc(2026, 10, 3);
final paceFirstRecordMonth = DateTime.utc(2025, 12, 1);

const paceDining = 'dining';
const paceGroceries = 'groceries';
const paceTransport = 'transport';
const paceSalary = 'salary';

final paceDiningLimit = Decimal.fromInt(350);
final paceGroceriesLimit = Decimal.fromInt(450);
final paceTransportLimit = Decimal.fromInt(120);

final paceAccountID = testId(1);
final paceCategoryIDs = {
  paceDining: testId(2),
  paceGroceries: testId(3),
  paceTransport: testId(4),
  paceSalary: testId(5),
};

const _historyMonthCount = 10;
const _lastHistoryMonthIndex = _historyMonthCount - 1;
const _salaryMonthCount = 11;
const _diningMonthly = '400.00';
const _diningSeptember = '432.80';
const _groceriesEvenMonth = '280.00';
const _groceriesOddMonth = '328.00';
const _transportMonthly = '150.00';
const _transportSeptember = '140.40';
const _salaryMonthly = '3200.00';
const _historyStartYear = 2025;
const _historyStartMonth = 12;

DateTime _historyDay(int monthIndex, int day) =>
    DateTime.utc(_historyStartYear, _historyStartMonth + monthIndex, day);

PaceRow _row(String categoryKey, DateTime date, String amount) =>
    (categoryKey: categoryKey, date: date, amount: amount);

List<PaceRow> _diningRows() {
  return [
    for (var i = 0; i < _lastHistoryMonthIndex; i++)
      _row(paceDining, _historyDay(i, 5), _diningMonthly),
    _row(paceDining, _historyDay(_lastHistoryMonthIndex, 5), _diningSeptember),
  ];
}

List<PaceRow> _groceriesRows() {
  return [
    for (var i = 0; i < _historyMonthCount; i++)
      _row(
        paceGroceries,
        _historyDay(i, 12),
        i.isEven ? _groceriesEvenMonth : _groceriesOddMonth,
      ),
  ];
}

List<PaceRow> _transportRows() {
  return [
    for (var i = 1; i < _lastHistoryMonthIndex; i++)
      _row(paceTransport, _historyDay(i, 20), _transportMonthly),
    _row(paceTransport, DateTime.utc(2026, 9, 30), _transportSeptember),
  ];
}

List<PaceRow> _salaryRows() {
  return [
    for (var i = 0; i < _salaryMonthCount; i++)
      _row(paceSalary, _historyDay(i, 1), _salaryMonthly),
  ];
}

List<PaceRow> _octoberRows() {
  return [
    _row(paceDining, DateTime.utc(2026, 10, 1), '45.00'),
    _row(paceGroceries, DateTime.utc(2026, 10, 2), '73.50'),
    _row(paceDining, DateTime.utc(2026, 10, 3), '38.90'),
    _row(paceTransport, DateTime.utc(2026, 10, 3), '10.00'),
    _row(paceGroceries, DateTime.utc(2026, 10, 15), '60.00'),
  ];
}

List<PaceRow> paceRows() {
  return [
    ..._diningRows(),
    ..._groceriesRows(),
    ..._transportRows(),
    ..._salaryRows(),
    ..._octoberRows(),
  ];
}

List<AnalysisItem> paceItems() {
  return [
    for (final row in paceRows())
      AnalysisItem(
        bucketID: paceCategoryIDs[row.categoryKey],
        amount: Decimal.parse(row.amount),
        date: row.date,
        kind: row.categoryKey == paceSalary
            ? CategoryKind.income
            : CategoryKind.expense,
      ),
  ];
}

TransactionCategory _category(String key, CategoryKind kind) {
  return TransactionCategory(
    id: paceCategoryIDs[key]!,
    name: key,
    kind: kind,
    colorHex: '#000000',
    includeInAnalysis: true,
    parentID: null,
    symbol: 'tag',
  );
}

Entry _entry(int index, PaceRow row) {
  final isIncome = row.categoryKey == paceSalary;
  final amount = Decimal.parse(row.amount);
  return Entry(
    id: testId(100 + index),
    amount: isIncome ? amount : -amount,
    name: row.categoryKey,
    sourceID: paceAccountID,
    categoryID: paceCategoryIDs[row.categoryKey],
    date: row.date,
  );
}

void addPaceHistory(Ledger ledger) {
  ledger.addAccount(
    Account(id: paceAccountID, name: 'Checking', type: AccountType.checking),
  );
  for (final key in [paceDining, paceGroceries, paceTransport]) {
    ledger.addCategory(_category(key, CategoryKind.expense));
  }
  ledger.addCategory(_category(paceSalary, CategoryKind.income));
  final rows = paceRows();
  for (var i = 0; i < rows.length; i++) {
    ledger.addEntry(_entry(i, rows[i]));
  }
}
