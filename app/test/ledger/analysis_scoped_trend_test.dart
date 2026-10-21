import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ledger/analysis/breakdowns/analysis_category_scope.dart';
import 'package:spendwise/ledger/analysis/summaries/month_spread.dart';
import 'package:spendwise/ledger/analysis/breakdowns/scoped_trend.dart';

import 'analysis_test_support.dart';

final _main = testId(1);
final _childA = testId(2);
final _childB = testId(3);
final _other = testId(4);
final _otherChild = testId(5);
final _checking = testId(10);
final _flagged = testId(11);

final _today = DateTime.utc(2027, 5, 15);
final _day = DateTime.utc(2027, 1, 10);

class _Booking {
  _Booking(this.categoryID, this.amount, {DateTime? date})
    : date = date ?? _day;

  final String? categoryID;
  final int amount;
  final DateTime date;
}

TransactionCategory _category(
  String id, {
  String? parent,
  CategoryKind kind = CategoryKind.expense,
}) => TransactionCategory(
  id: id,
  name: id,
  kind: kind,
  colorHex: '#000000',
  includeInAnalysis: true,
  parentID: parent,
  symbol: 'tag',
  lifecycle: LifecycleState.active,
);

LedgerState _state({
  required List<TransactionCategory> categories,
  required List<_Booking> bookings,
  int syntheticTransfer = 0,
  DateTime? transferDate,
}) {
  final state = LedgerState()
    ..addAccount(
      Account(id: _checking, name: 'Checking', type: AccountType.checking),
    )
    ..addAccount(
      Account(
        id: _flagged,
        name: 'Flagged',
        type: AccountType.savings,
        incomingTransfersAsExpenses: true,
      ),
    );
  categories.forEach(state.addCategory);
  Entry entry(
    int amount, {
    String? categoryID,
    String? destinationID,
    DateTime? date,
  }) => Entry(
    id: null,
    amount: Decimal.fromInt(amount),
    name: 'entry',
    sourceID: _checking,
    destinationID: destinationID,
    categoryID: categoryID,
    date: date ?? _day,
    includeInAnalysis: true,
  );
  for (final booking in bookings) {
    state.addEntry(
      entry(
        -booking.amount,
        categoryID: booking.categoryID,
        date: booking.date,
      ),
    );
  }
  if (syntheticTransfer > 0) {
    state.addEntry(
      entry(
        syntheticTransfer,
        destinationID: _flagged,
        date: transferDate ?? _day,
      ),
    );
  }
  return state;
}

LedgerState _coreState() => _state(
  categories: [
    _category(_main),
    _category(_childA, parent: _main),
    _category(_childB, parent: _main),
    _category(_other),
    _category(_otherChild, parent: _other),
  ],
  bookings: [
    _Booking(_childA, 2, date: DateTime.utc(2027, 1, 10)),
    _Booking(_childB, 3, date: DateTime.utc(2027, 1, 10)),
    _Booking(_main, 5, date: DateTime.utc(2027, 1, 10)),
    _Booking(_childA, 7, date: DateTime.utc(2027, 5, 31)),
    _Booking(_childB, 11, date: DateTime.utc(2027, 5, 31)),
    _Booking(_main, 13, date: DateTime.utc(2027, 5, 31)),
    _Booking(_childA, 17, date: DateTime.utc(2027, 6, 10)),
    _Booking(_childB, 19, date: DateTime.utc(2027, 12, 5)),
    _Booking(_main, 23, date: DateTime.utc(2027, 6, 10)),
    _Booking(_main, 29, date: DateTime.utc(2027, 12, 5)),
    _Booking(_otherChild, 50, date: DateTime.utc(2027, 1, 12)),
  ],
);

ScopedTrend _trend(
  LedgerState state, {
  required String? main,
  required AnalysisCategoryScope scope,
  CategoryKind kind = CategoryKind.expense,
  DateTime? period,
  AnalysisPeriodMode mode = AnalysisPeriodMode.month,
}) => scopedTrend(
  mainBucketID: main,
  scope: scope,
  kind: kind,
  period: period ?? DateTime.utc(2027, 5, 15),
  mode: mode,
  today: _today,
  state: state,
  items: Accounting.analysisItems(state),
);

MonthSlot _slot(ScopedTrend trend, int year, int month) => trend.slots
    .firstWhere((slot) => slot.month == DateTime.utc(year, month, 1));

void main() {
  test('month mode all scope sums children and direct', () {
    final result = _trend(
      _coreState(),
      main: _main,
      scope: const AnalysisCategoryScope.all(),
    );

    expect(result.slots, hasLength(12));
    expect(result.endMonth, DateTime.utc(2027, 5, 1));
    expect(_slot(result, 2027, 1).total, Decimal.fromInt(10));
    expect(_slot(result, 2027, 1).itemCount, 3);
    expect(_slot(result, 2027, 5).total, Decimal.fromInt(31));
    expect(_slot(result, 2027, 5).itemCount, 3);
    expect(_slot(result, 2027, 2).total, Decimal.zero);
    expect(_slot(result, 2027, 2).itemCount, 0);
  });

  test('includes months after today in year mode', () {
    final result = _trend(
      _coreState(),
      main: _main,
      scope: const AnalysisCategoryScope.all(),
      period: DateTime.utc(2027, 4, 2),
      mode: AnalysisPeriodMode.year,
    );

    expect(result.endMonth, DateTime.utc(2027, 12, 1));
    expect(_slot(result, 2027, 12).total, Decimal.fromInt(48));
  });

  test('future month anchor throws', () {
    final state = _coreState();

    expect(
      () => _trend(
        state,
        main: _main,
        scope: const AnalysisCategoryScope.all(),
        period: DateTime.utc(2027, 6, 1),
      ),
      throwsArgumentError,
    );
  });

  test('future year throws', () {
    final state = _coreState();

    expect(
      () => _trend(
        state,
        main: _main,
        scope: const AnalysisCategoryScope.all(),
        period: DateTime.utc(2028, 3, 1),
        mode: AnalysisPeriodMode.year,
      ),
      throwsArgumentError,
    );
  });

  test('invalid child parent pairs throw', () {
    final state = _coreState();
    ScopedTrend trend(String? main, String child) => _trend(
      state,
      main: main,
      scope: AnalysisCategoryScope.subcategory(child),
    );

    expect(() => trend(_other, _childA), throwsArgumentError);
    expect(() => trend(null, _childA), throwsArgumentError);
    expect(() => trend(_main, testId(99)), throwsArgumentError);
    expect(() => trend(_main, _main), throwsArgumentError);
    expect(() => trend(_childB, _childA), throwsArgumentError);
  });
}
