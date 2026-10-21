import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ledger/analysis/breakdowns/category_breakdown.dart';

import 'analysis_test_support.dart';

final _main = testId(1);
final _childA = testId(2);
final _childB = testId(3);
final _childless = testId(4);
final _checking = testId(10);
final _flagged = testId(11);
const _syntheticID = 'transfer-expense:savings';

final _window = DateRange(DateTime.utc(2026, 1, 1), DateTime.utc(2026, 2, 1));
final _day = DateTime.utc(2026, 1, 10);
final _incomeMain = testId(5);
final _incomeChild = testId(6);

class _Booking {
  _Booking(this.categoryID, this.amount, {this.income = false, DateTime? date})
    : date = date ?? _day;

  final String? categoryID;
  final int amount;
  final bool income;
  final DateTime date;
}

TransactionCategory _category(
  String id, {
  String? parent,
  String? name,
  CategoryKind kind = CategoryKind.expense,
  LifecycleState lifecycle = LifecycleState.active,
  bool includeInAnalysis = true,
}) => TransactionCategory(
  id: id,
  name: name ?? id,
  kind: kind,
  colorHex: '#000000',
  includeInAnalysis: includeInAnalysis,
  parentID: parent,
  symbol: 'tag',
  lifecycle: lifecycle,
);

LedgerState _state({
  required List<TransactionCategory> categories,
  required List<_Booking> bookings,
  int syntheticTransfer = 0,
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
        booking.income ? booking.amount : -booking.amount,
        categoryID: booking.categoryID,
        date: booking.date,
      ),
    );
  }
  if (syntheticTransfer > 0) {
    state.addEntry(entry(syntheticTransfer, destinationID: _flagged));
  }
  return state;
}

PeriodBreakdown _breakdown(
  LedgerState state,
  BreakdownLevel level, {
  CategoryKind kind = CategoryKind.expense,
}) => categoryBreakdown(
  items: Accounting.analysisItems(state),
  state: state,
  window: _window,
  kind: kind,
  level: level,
);

BreakdownRow _row(
  String? bucketID,
  String? mainBucketID,
  int amount, {
  bool isDirect = false,
  required String share,
}) => BreakdownRow(
  bucketID: bucketID,
  mainBucketID: mainBucketID,
  isDirect: isDirect,
  amount: Decimal.fromInt(amount),
  sharePercent: Decimal.parse(share),
);

Decimal _shareSum(List<BreakdownRow> rows) =>
    rows.fold(Decimal.zero, (sum, row) => sum + row.sharePercent);

void _expectTenths(List<BreakdownRow> rows) {
  for (final row in rows) {
    expect(row.sharePercent.shift(1).isInteger, isTrue);
  }
}

LedgerState _mixedState() => _state(
  categories: [
    _category(_main),
    _category(_childA, parent: _main),
    _category(_childB, parent: _main),
    _category(_childless),
  ],
  bookings: [
    _Booking(_childA, 20),
    _Booking(_childB, 30),
    _Booking(_main, 10),
    _Booking(_childless, 15),
    _Booking(null, 5),
  ],
  syntheticTransfer: 20,
);

void main() {
  test('categories level rolls children into the main', () {
    final result = _breakdown(_mixedState(), BreakdownLevel.categories);

    expect(result.total, Decimal.fromInt(100));
    expect(result.rows, [
      _row(_main, _main, 60, share: '60.0'),
      _row(_syntheticID, _syntheticID, 20, share: '20.0'),
      _row(_childless, _childless, 15, share: '15.0'),
      _row(null, null, 5, share: '5.0'),
    ]);
  });

  test('subcategories level splits leaves and adds a direct row', () {
    final result = _breakdown(_mixedState(), BreakdownLevel.subcategories);

    expect(result.total, Decimal.fromInt(100));
    expect(result.rows, [
      _row(_childB, _main, 30, share: '30.0'),
      _row(_childA, _main, 20, share: '20.0'),
      _row(_syntheticID, _syntheticID, 20, share: '20.0'),
      _row(_childless, _childless, 15, share: '15.0'),
      _row(_main, _main, 10, isDirect: true, share: '10.0'),
      _row(null, null, 5, share: '5.0'),
    ]);
  });

  test('a child excluded from analysis still gives the main a direct row', () {
    final state = _state(
      categories: [
        _category(_main),
        _category(_childA, parent: _main, includeInAnalysis: false),
      ],
      bookings: [_Booking(_main, 10)],
    );

    final rows = _breakdown(state, BreakdownLevel.subcategories).rows;

    expect(rows, [_row(_main, _main, 10, isDirect: true, share: '100.0')]);
  });

  test('an income hierarchy groups like an expense hierarchy', () {
    final state = _state(
      categories: [
        _category(_main, kind: CategoryKind.income),
        _category(_childA, parent: _main, kind: CategoryKind.income),
      ],
      bookings: [
        _Booking(_childA, 20, income: true),
        _Booking(_main, 10, income: true),
      ],
    );

    final categories = _breakdown(
      state,
      BreakdownLevel.categories,
      kind: CategoryKind.income,
    );
    final subcategories = _breakdown(
      state,
      BreakdownLevel.subcategories,
      kind: CategoryKind.income,
    );

    expect(categories.rows, [_row(_main, _main, 30, share: '100.0')]);
    expect(subcategories.rows, [
      _row(_childA, _main, 20, share: '66.7'),
      _row(_main, _main, 10, isDirect: true, share: '33.3'),
    ]);
    expect(subcategories.total, Decimal.fromInt(30));
  });

  test('three equal amounts give the extra tenth to the smallest identity', () {
    final first = testId(20);
    final second = testId(21);
    final third = testId(22);
    final state = _state(
      categories: [_category(first), _category(second), _category(third)],
      bookings: [_Booking(first, 1), _Booking(second, 1), _Booking(third, 1)],
    );

    final result = _breakdown(state, BreakdownLevel.categories);

    expect(result.total, Decimal.fromInt(3));
    expect(result.rows, [
      _row(first, first, 1, share: '33.4'),
      _row(second, second, 1, share: '33.3'),
      _row(third, third, 1, share: '33.3'),
    ]);
    expect(_shareSum(result.rows), Decimal.parse('100.0'));
    _expectTenths(result.rows);
  });

  test('subcategory shares use the whole period total', () {
    final result = _breakdown(_mixedState(), BreakdownLevel.subcategories);

    final childA = result.rows.firstWhere((row) => row.bucketID == _childA);

    expect(childA.sharePercent, Decimal.parse('20.0'));
    expect(childA.sharePercent, isNot(Decimal.parse('33.3')));
    expect(_shareSum(result.rows), Decimal.parse('100.0'));
    _expectTenths(result.rows);
  });

  test('null and synthetic buckets survive both levels', () {
    final state = _state(
      categories: const [],
      bookings: [_Booking(null, 5)],
      syntheticTransfer: 20,
    );

    for (final level in BreakdownLevel.values) {
      expect(_breakdown(state, level).rows, [
        _row(_syntheticID, _syntheticID, 20, share: '80.0'),
        _row(null, null, 5, share: '20.0'),
      ]);
    }
  });

  test('an empty period has zero total and no rows', () {
    final state = _state(categories: const [], bookings: []);

    for (final level in BreakdownLevel.values) {
      final result = _breakdown(state, level);
      expect(result.total, Decimal.zero);
      expect(result.rows, isEmpty);
      expect(_shareSum(result.rows), Decimal.zero);
    }
  });

  test('expense kind keeps only expense items inside the half-open window', () {
    final state = _state(
      categories: [
        _category(_main),
        _category(_childA, parent: _main),
        _category(_incomeMain, kind: CategoryKind.income),
        _category(_incomeChild, parent: _incomeMain, kind: CategoryKind.income),
      ],
      bookings: [
        _Booking(_childA, 1, date: DateTime.utc(2025, 12, 31)),
        _Booking(_childA, 2, date: DateTime.utc(2026, 1, 1)),
        _Booking(_childA, 4, date: DateTime.utc(2026, 1, 31)),
        _Booking(_childA, 8, date: DateTime.utc(2026, 2, 1)),
        _Booking(_childA, 16, date: DateTime.utc(2026, 3, 1)),
        _Booking(_main, 32, date: DateTime.utc(2026, 1, 15)),
        _Booking(
          _incomeChild,
          256,
          income: true,
          date: DateTime.utc(2025, 12, 31),
        ),
        _Booking(_incomeChild, 3, income: true, date: DateTime.utc(2026, 1, 1)),
        _Booking(
          _incomeChild,
          5,
          income: true,
          date: DateTime.utc(2026, 1, 31),
        ),
        _Booking(
          _incomeChild,
          128,
          income: true,
          date: DateTime.utc(2026, 2, 1),
        ),
        _Booking(
          _incomeMain,
          64,
          income: true,
          date: DateTime.utc(2026, 1, 15),
        ),
      ],
    );
    final categories = _breakdown(state, BreakdownLevel.categories);
    final subcategories = _breakdown(state, BreakdownLevel.subcategories);

    expect(categories.total, Decimal.fromInt(38));
    expect(categories.rows, [_row(_main, _main, 38, share: '100.0')]);
    expect(subcategories.total, Decimal.fromInt(38));
    expect(subcategories.rows, [
      _row(_main, _main, 32, isDirect: true, share: '84.2'),
      _row(_childA, _main, 6, share: '15.8'),
    ]);
  });
}
