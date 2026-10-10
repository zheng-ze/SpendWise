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

class _Booking {
  const _Booking(this.categoryID, this.amount, {this.income = false});

  final String? categoryID;
  final int amount;
  final bool income;
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
  Entry entry(int amount, {String? categoryID, String? destinationID}) => Entry(
    id: null,
    amount: Decimal.fromInt(amount),
    name: 'entry',
    sourceID: _checking,
    destinationID: destinationID,
    categoryID: categoryID,
    date: _day,
    includeInAnalysis: true,
  );
  for (final booking in bookings) {
    state.addEntry(
      entry(
        booking.income ? booking.amount : -booking.amount,
        categoryID: booking.categoryID,
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
    const _Booking(null, 5),
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
        bookings: [_Booking(_childless, 5), const _Booking(null, 5)],
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
        bookings: [const _Booking(null, 5)],
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
      final state = _state(categories: const [], bookings: const []);

      for (final level in BreakdownLevel.values) {
        final result = _breakdown(state, level);
        expect(result.total, Decimal.zero);
        expect(result.rows, isEmpty);
      }
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
