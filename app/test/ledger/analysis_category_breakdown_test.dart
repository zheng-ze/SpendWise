import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ledger/analysis/category_breakdown.dart';

String _id(int n) => '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';

final _main = _id(1);
final _childA = _id(2);
final _childB = _id(3);
final _childless = _id(4);
final _checking = _id(10);
final _flagged = _id(11);
const _syntheticID = 'transfer-expense:savings';

final _window = DateRange(DateTime.utc(2026, 1, 1), DateTime.utc(2026, 2, 1));
final _day = DateTime.utc(2026, 1, 10);
final _incomeMain = _id(5);
final _incomeChild = _id(6);

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
}) => BreakdownRow(
  bucketID: bucketID,
  mainBucketID: mainBucketID,
  isDirect: isDirect,
  amount: Decimal.fromInt(amount),
);

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
        _row(_main, _main, 60),
        _row(_syntheticID, _syntheticID, 20),
        _row(_childless, _childless, 15),
        _row(null, null, 5),
      ]);
    });

    test('subcategories level splits leaves and adds a direct row', () {
      final result = _breakdown(_mixedState(), BreakdownLevel.subcategories);

      expect(result.total, Decimal.fromInt(100));
      expect(result.rows, [
        _row(_childB, _main, 30),
        _row(_childA, _main, 20),
        _row(_syntheticID, _syntheticID, 20),
        _row(_childless, _childless, 15),
        _row(_main, _main, 10, isDirect: true),
        _row(null, null, 5),
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

      expect(rows, [_row(_childA, _main, 20)]);
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
        _row(_main, _main, 10),
      ]);
      expect(_breakdown(withUnusedChild, BreakdownLevel.subcategories).rows, [
        _row(_main, _main, 10, isDirect: true),
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

      expect(rows, [_row(_main, _main, 10, isDirect: true)]);
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

        expect(rows, [_row(_main, _main, 10, isDirect: true)]);
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

      expect(categories.rows, [_row(_main, _main, 30)]);
      expect(subcategories.rows, [
        _row(_childA, _main, 20),
        _row(_main, _main, 10, isDirect: true),
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

  group('boundaries', () {
    test('null and synthetic buckets survive both levels', () {
      final state = _state(
        categories: const [],
        bookings: [_Booking(null, 5)],
        syntheticTransfer: 20,
      );

      for (final level in BreakdownLevel.values) {
        expect(_breakdown(state, level).rows, [
          _row(_syntheticID, _syntheticID, 20),
          _row(null, null, 5),
        ]);
      }
    });

    test('an empty period has zero total and no rows', () {
      final state = _state(categories: const [], bookings: []);

      for (final level in BreakdownLevel.values) {
        final result = _breakdown(state, level);
        expect(result.total, Decimal.zero);
        expect(result.rows, isEmpty);
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
        expect(categories.rows, [_row(_main, _main, 38)]);
        expect(subcategories.total, Decimal.fromInt(38));
        expect(subcategories.rows, [
          _row(_main, _main, 32, isDirect: true),
          _row(_childA, _main, 6),
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
      expect(categories.rows, [_row(_incomeMain, _incomeMain, 72)]);
      expect(subcategories.total, Decimal.fromInt(72));
      expect(subcategories.rows, [
        _row(_incomeMain, _incomeMain, 64, isDirect: true),
        _row(_incomeChild, _incomeMain, 8),
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

    test('results differ by level, row amount, id and isDirect', () {
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
        isNot(withRow(_row(first.bucketID, first.mainBucketID, 31))),
      );
      expect(base, isNot(withRow(_row(_id(99), first.mainBucketID, 30))));
      expect(
        base,
        isNot(
          withRow(_row(first.bucketID, first.mainBucketID, 30, isDirect: true)),
        ),
      );
    });

    test('the returned row list rejects mutation', () {
      final result = _breakdown(_mixedState(), BreakdownLevel.categories);

      expect(
        () => result.rows.add(_row(null, null, 1)),
        throwsUnsupportedError,
      );
    });
  });
}
