import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ledger/analysis/category_breakdown.dart';

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
  group('mixed hierarchy', () {
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
  });

  group('direct rows', () {
    test('a main with children and only child bookings has no direct row', () {
      final state = _state(
        categories: [
          _category(_main),
          _category(_childA, parent: _main),
        ],
        bookings: [_Booking(_childA, 20)],
      );

      final rows = _breakdown(state, BreakdownLevel.subcategories).rows;

      expect(rows, [_row(_childA, _main, 20, share: '100.0')]);
    });

    test('an unused child turns the ordinary main row into a direct row', () {
      final booked = [_Booking(_main, 10)];
      final childless = _state(
        categories: [_category(_main)],
        bookings: booked,
      );
      final withUnusedChild = _state(
        categories: [
          _category(_main),
          _category(_childA, parent: _main),
        ],
        bookings: booked,
      );

      expect(_breakdown(childless, BreakdownLevel.subcategories).rows, [
        _row(_main, _main, 10, share: '100.0'),
      ]);
      expect(_breakdown(withUnusedChild, BreakdownLevel.subcategories).rows, [
        _row(_main, _main, 10, isDirect: true, share: '100.0'),
      ]);
    });

    test('a main whose only child is archived still gets a direct row', () {
      final state = _state(
        categories: [
          _category(_main),
          _category(_childA, parent: _main, lifecycle: LifecycleState.archived),
        ],
        bookings: [_Booking(_main, 10)],
      );

      final rows = _breakdown(state, BreakdownLevel.subcategories).rows;

      expect(rows, [_row(_main, _main, 10, isDirect: true, share: '100.0')]);
    });

    test(
      'a child excluded from analysis still gives the main a direct row',
      () {
        final state = _state(
          categories: [
            _category(_main),
            _category(_childA, parent: _main, includeInAnalysis: false),
          ],
          bookings: [_Booking(_main, 10)],
        );

        final rows = _breakdown(state, BreakdownLevel.subcategories).rows;

        expect(rows, [_row(_main, _main, 10, isDirect: true, share: '100.0')]);
      },
    );
  });

  group('income', () {
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
  });

  group('ordering', () {
    test('equal amounts follow identity regardless of insertion or names', () {
      LedgerState build(List<String> order, Map<String, String> names) =>
          _state(
            categories: [
              for (final id in order) _category(id, name: names[id]),
            ],
            bookings: [for (final id in order) _Booking(id, 10)],
            syntheticTransfer: 10,
          );
      final forward = build(
        [_childA, _childB],
        {_childA: 'Zebra', _childB: 'Apple'},
      );
      final reversed = build(
        [_childB, _childA],
        {_childA: 'Apple', _childB: 'Zebra'},
      );

      for (final state in [forward, reversed]) {
        final ids = _breakdown(
          state,
          BreakdownLevel.categories,
        ).rows.map((row) => row.bucketID);
        expect(ids, [_childA, _childB, _syntheticID]);
      }
    });

    test('a null bucket sorts after a real bucket of equal amount', () {
      final state = _state(
        categories: [_category(_childless)],
        bookings: [_Booking(_childless, 5), _Booking(null, 5)],
      );

      final ids = _breakdown(
        state,
        BreakdownLevel.subcategories,
      ).rows.map((row) => row.bucketID);

      expect(ids, [_childless, null]);
    });
  });

  group('shares', () {
    test(
      'three equal amounts give the extra tenth to the smallest identity',
      () {
        final first = testId(20);
        final second = testId(21);
        final third = testId(22);
        final state = _state(
          categories: [_category(first), _category(second), _category(third)],
          bookings: [
            _Booking(first, 1),
            _Booking(second, 1),
            _Booking(third, 1),
          ],
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
      },
    );

    test('reversed insertion and renamed categories give identical output', () {
      LedgerState build(List<String> order, Map<String, String> names) =>
          _state(
            categories: [
              for (final id in order) _category(id, name: names[id]),
            ],
            bookings: [for (final id in order) _Booking(id, 1)],
          );
      final ids = [testId(20), testId(21), testId(22)];
      final forward = build(ids, {
        testId(20): 'Zebra',
        testId(21): 'Mango',
        testId(22): 'Apple',
      });
      final reversed = build(ids.reversed.toList(), {
        testId(20): 'Apple',
        testId(21): 'Zebra',
        testId(22): 'Mango',
      });

      final forwardRows = _breakdown(forward, BreakdownLevel.categories).rows;
      final reversedRows = _breakdown(reversed, BreakdownLevel.categories).rows;

      expect(reversedRows, forwardRows);
      expect(forwardRows.first.sharePercent, Decimal.parse('33.4'));
    });

    test('remainder priority differs from amount rank', () {
      final high = testId(20);
      final lowA = testId(21);
      final lowB = testId(22);
      final state = _state(
        categories: [_category(high), _category(lowA), _category(lowB)],
        bookings: [_Booking(high, 7), _Booking(lowA, 2), _Booking(lowB, 2)],
      );

      final result = _breakdown(state, BreakdownLevel.categories);

      expect(result.total, Decimal.fromInt(11));
      expect(result.rows, [
        _row(high, high, 7, share: '63.6'),
        _row(lowA, lowA, 2, share: '18.2'),
        _row(lowB, lowB, 2, share: '18.2'),
      ]);
      expect(_shareSum(result.rows), Decimal.parse('100.0'));
      _expectTenths(result.rows);
    });

    test(
      'a remainder tie at the cutoff breaks by identity, not amount rank',
      () {
        final smallA = testId(20);
        final smallB = testId(21);
        final large = testId(22);
        final state = _state(
          categories: [_category(smallA), _category(smallB), _category(large)],
          bookings: [
            _Booking(smallA, 1),
            _Booking(smallB, 1),
            _Booking(large, 4),
          ],
        );

        final result = _breakdown(state, BreakdownLevel.categories);

        expect(result.total, Decimal.fromInt(6));
        expect(result.rows, [
          _row(large, large, 4, share: '66.6'),
          _row(smallA, smallA, 1, share: '16.7'),
          _row(smallB, smallB, 1, share: '16.7'),
        ]);
        expect(_shareSum(result.rows), Decimal.parse('100.0'));
        _expectTenths(result.rows);
      },
    );

    test(
      'equal real, synthetic and null amounts order lexically null-last',
      () {
        final state = _state(
          categories: [_category(_childless)],
          bookings: [_Booking(_childless, 5), _Booking(null, 5)],
          syntheticTransfer: 5,
        );

        final result = _breakdown(state, BreakdownLevel.categories);

        expect(result.total, Decimal.fromInt(15));
        expect(result.rows, [
          _row(_childless, _childless, 5, share: '33.4'),
          _row(_syntheticID, _syntheticID, 5, share: '33.3'),
          _row(null, null, 5, share: '33.3'),
        ]);
        expect(_shareSum(result.rows), Decimal.parse('100.0'));
        _expectTenths(result.rows);
      },
    );

    test('a tiny positive row stays present with a 0.0 share', () {
      final big = testId(20);
      final tiny = testId(21);
      final state = _state(
        categories: [_category(big), _category(tiny)],
        bookings: [_Booking(big, 9999)],
      );
      state.addEntry(
        Entry(
          id: null,
          amount: Decimal.parse('-0.0001'),
          name: 'entry',
          sourceID: _checking,
          categoryID: tiny,
          date: _day,
          includeInAnalysis: true,
        ),
      );

      final result = _breakdown(state, BreakdownLevel.categories);

      expect(result.total, Decimal.parse('9999.0001'));
      expect(result.rows, [
        BreakdownRow(
          bucketID: big,
          mainBucketID: big,
          isDirect: false,
          amount: Decimal.fromInt(9999),
          sharePercent: Decimal.parse('100.0'),
        ),
        BreakdownRow(
          bucketID: tiny,
          mainBucketID: tiny,
          isDirect: false,
          amount: Decimal.parse('0.0001'),
          sharePercent: Decimal.parse('0.0'),
        ),
      ]);
      expect(_shareSum(result.rows), Decimal.parse('100.0'));
      _expectTenths(result.rows);
    });

    test('a one-row period gives 100.0', () {
      final state = _state(
        categories: [_category(_childless)],
        bookings: [_Booking(_childless, 42)],
      );

      final result = _breakdown(state, BreakdownLevel.categories);

      expect(result.rows, [_row(_childless, _childless, 42, share: '100.0')]);
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
  });

  group('boundaries', () {
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
  });

  group('filters', () {
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

    test(
      'expense kind keeps only expense items inside the half-open window',
      () {
        final categories = _breakdown(state, BreakdownLevel.categories);
        final subcategories = _breakdown(state, BreakdownLevel.subcategories);

        expect(categories.total, Decimal.fromInt(38));
        expect(categories.rows, [_row(_main, _main, 38, share: '100.0')]);
        expect(subcategories.total, Decimal.fromInt(38));
        expect(subcategories.rows, [
          _row(_main, _main, 32, isDirect: true, share: '84.2'),
          _row(_childA, _main, 6, share: '15.8'),
        ]);
      },
    );

    test('income kind keeps only income items inside the half-open window', () {
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

      expect(categories.total, Decimal.fromInt(72));
      expect(categories.rows, [
        _row(_incomeMain, _incomeMain, 72, share: '100.0'),
      ]);
      expect(subcategories.total, Decimal.fromInt(72));
      expect(subcategories.rows, [
        _row(_incomeMain, _incomeMain, 64, isDirect: true, share: '88.9'),
        _row(_incomeChild, _incomeMain, 8, share: '11.1'),
      ]);
    });
  });

  group('value contracts', () {
    test('independent equal results are equal with equal hash codes', () {
      final first = _breakdown(_mixedState(), BreakdownLevel.subcategories);
      final second = _breakdown(_mixedState(), BreakdownLevel.subcategories);

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first.rows.first.hashCode, second.rows.first.hashCode);
    });

    test('results differ by level, row amount, share, id and isDirect', () {
      final base = _breakdown(_mixedState(), BreakdownLevel.subcategories);
      PeriodBreakdown withRow(BreakdownRow row) => PeriodBreakdown(
        window: base.window,
        kind: base.kind,
        level: base.level,
        total: base.total,
        rows: [row, ...base.rows.skip(1)],
      );
      final first = base.rows.first;

      expect(base, isNot(_breakdown(_mixedState(), BreakdownLevel.categories)));
      expect(
        base,
        isNot(
          withRow(_row(first.bucketID, first.mainBucketID, 31, share: '30.0')),
        ),
      );
      expect(
        base,
        isNot(
          withRow(_row(first.bucketID, first.mainBucketID, 30, share: '30.1')),
        ),
      );
      expect(
        base,
        isNot(withRow(_row(testId(99), first.mainBucketID, 30, share: '30.0'))),
      );
      expect(
        base,
        isNot(
          withRow(
            _row(
              first.bucketID,
              first.mainBucketID,
              30,
              isDirect: true,
              share: '30.0',
            ),
          ),
        ),
      );
    });

    test('the returned row list rejects mutation', () {
      final result = _breakdown(_mixedState(), BreakdownLevel.categories);

      expect(
        () => result.rows.add(_row(null, null, 1, share: '0.0')),
        throwsUnsupportedError,
      );
    });
  });
}
