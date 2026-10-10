import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ledger/analysis/analysis_category_scope.dart';
import 'package:spendwise/ledger/analysis/analysis_period_mode.dart';
import 'package:spendwise/ledger/analysis/completeness.dart';
import 'package:spendwise/ledger/analysis/month_spread.dart';
import 'package:spendwise/ledger/analysis/scoped_trend.dart';

String _id(int n) => '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';

final _main = _id(1);
final _childA = _id(2);
final _childB = _id(3);
final _other = _id(4);
final _otherChild = _id(5);
final _checking = _id(10);
final _flagged = _id(11);
final _incomeMain = _id(20);
final _incomeChild = _id(21);
const _syntheticID = 'transfer-expense:savings';

final _today = DateTime.utc(2027, 5, 15);
final _day = DateTime.utc(2027, 1, 10);

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
        booking.income ? booking.amount : -booking.amount,
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
  group('core scopes', () {
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

    test('month mode subcategory scope keeps only that child', () {
      final result = _trend(
        _coreState(),
        main: _main,
        scope: AnalysisCategoryScope.subcategory(_childA),
      );

      expect(_slot(result, 2027, 1).total, Decimal.fromInt(2));
      expect(_slot(result, 2027, 1).itemCount, 1);
      expect(_slot(result, 2027, 5).total, Decimal.fromInt(7));
      expect(_slot(result, 2027, 5).itemCount, 1);
      expect(_slot(result, 2027, 2).total, Decimal.zero);
      expect(_slot(result, 2027, 2).itemCount, 0);
    });

    test('month mode direct scope keeps only main bookings', () {
      final result = _trend(
        _coreState(),
        main: _main,
        scope: const AnalysisCategoryScope.direct(),
      );

      expect(_slot(result, 2027, 1).total, Decimal.fromInt(5));
      expect(_slot(result, 2027, 1).itemCount, 1);
      expect(_slot(result, 2027, 5).total, Decimal.fromInt(13));
      expect(_slot(result, 2027, 5).itemCount, 1);
    });

    test('year mode keeps january and may values', () {
      final state = _coreState();
      final all = _trend(
        state,
        main: _main,
        scope: const AnalysisCategoryScope.all(),
        period: DateTime.utc(2027, 3, 20),
        mode: AnalysisPeriodMode.year,
      );
      final sub = _trend(
        state,
        main: _main,
        scope: AnalysisCategoryScope.subcategory(_childA),
        period: DateTime.utc(2027, 3, 20),
        mode: AnalysisPeriodMode.year,
      );
      final direct = _trend(
        state,
        main: _main,
        scope: const AnalysisCategoryScope.direct(),
        period: DateTime.utc(2027, 3, 20),
        mode: AnalysisPeriodMode.year,
      );

      for (final result in [all, sub, direct]) {
        expect(result.slots, hasLength(12));
        expect(result.endMonth, DateTime.utc(2027, 12, 1));
        expect(result.slots.first.month, DateTime.utc(2027, 1, 1));
        expect(result.slots.last.month, DateTime.utc(2027, 12, 1));
      }
      expect(_slot(all, 2027, 1).total, Decimal.fromInt(10));
      expect(_slot(all, 2027, 5).total, Decimal.fromInt(31));
      expect(_slot(all, 2027, 5).itemCount, 3);
      expect(_slot(sub, 2027, 1).total, Decimal.fromInt(2));
      expect(_slot(sub, 2027, 5).total, Decimal.fromInt(7));
      expect(_slot(direct, 2027, 1).total, Decimal.fromInt(5));
      expect(_slot(direct, 2027, 5).total, Decimal.fromInt(13));
    });
  });

  group('current year masking', () {
    test('months after today are zero in year mode', () {
      final state = _coreState();
      ScopedTrend trend(AnalysisCategoryScope scope) => _trend(
        state,
        main: _main,
        scope: scope,
        period: DateTime.utc(2027, 4, 2),
        mode: AnalysisPeriodMode.year,
      );

      final all = trend(const AnalysisCategoryScope.all());
      final sub = trend(AnalysisCategoryScope.subcategory(_childA));
      final direct = trend(const AnalysisCategoryScope.direct());

      for (final result in [all, sub, direct]) {
        expect(result.slots, hasLength(12));
        for (var month = 6; month <= 12; month++) {
          expect(_slot(result, 2027, month).total, Decimal.zero);
          expect(_slot(result, 2027, month).itemCount, 0);
        }
      }
      expect(_slot(all, 2027, 5).total, Decimal.fromInt(31));
      expect(_slot(all, 2027, 5).itemCount, 3);
      expect(_slot(sub, 2027, 5).total, Decimal.fromInt(7));
      expect(_slot(sub, 2027, 5).itemCount, 1);
      expect(_slot(direct, 2027, 5).total, Decimal.fromInt(13));
      expect(_slot(direct, 2027, 5).itemCount, 1);
    });

    test('future months are masked for the income kind', () {
      final state = _state(
        categories: [
          _category(_incomeMain, kind: CategoryKind.income),
          _category(
            _incomeChild,
            parent: _incomeMain,
            kind: CategoryKind.income,
          ),
        ],
        bookings: [
          _Booking(
            _incomeChild,
            6,
            income: true,
            date: DateTime.utc(2027, 1, 10),
          ),
          _Booking(
            _incomeMain,
            9,
            income: true,
            date: DateTime.utc(2027, 1, 10),
          ),
          _Booking(
            _incomeChild,
            30,
            income: true,
            date: DateTime.utc(2027, 6, 10),
          ),
          _Booking(
            _incomeMain,
            40,
            income: true,
            date: DateTime.utc(2027, 12, 5),
          ),
        ],
      );
      ScopedTrend trend(AnalysisCategoryScope scope) => scopedTrend(
        mainBucketID: _incomeMain,
        scope: scope,
        kind: CategoryKind.income,
        period: DateTime.utc(2027, 4, 2),
        mode: AnalysisPeriodMode.year,
        today: _today,
        state: state,
        items: Accounting.analysisItems(state),
      );

      final all = trend(const AnalysisCategoryScope.all());
      final sub = trend(AnalysisCategoryScope.subcategory(_incomeChild));
      final direct = trend(const AnalysisCategoryScope.direct());

      for (final result in [all, sub, direct]) {
        expect(result.slots, hasLength(12));
        for (var month = 6; month <= 12; month++) {
          expect(_slot(result, 2027, month).total, Decimal.zero);
          expect(_slot(result, 2027, month).itemCount, 0);
        }
      }
      expect(_slot(all, 2027, 1).total, Decimal.fromInt(15));
      expect(_slot(all, 2027, 1).itemCount, 2);
      expect(_slot(sub, 2027, 1).total, Decimal.fromInt(6));
      expect(_slot(sub, 2027, 1).itemCount, 1);
      expect(_slot(direct, 2027, 1).total, Decimal.fromInt(9));
      expect(_slot(direct, 2027, 1).itemCount, 1);
    });
  });

  group('month boundaries', () {
    test('exactly twelve months with half-open inclusion', () {
      final state = _state(
        categories: [
          _category(_main),
          _category(_childA, parent: _main),
        ],
        bookings: [
          _Booking(_childA, 100, date: DateTime.utc(2026, 5, 31)),
          _Booking(_childA, 4, date: DateTime.utc(2026, 6, 1)),
          _Booking(_childA, 7, date: DateTime.utc(2027, 5, 31)),
          _Booking(_childA, 200, date: DateTime.utc(2027, 6, 1)),
        ],
      );
      final result = _trend(
        state,
        main: _main,
        scope: AnalysisCategoryScope.subcategory(_childA),
      );

      expect(result.slots, hasLength(12));
      expect(result.slots.first.month, DateTime.utc(2026, 6, 1));
      expect(result.slots.last.month, DateTime.utc(2027, 5, 1));
      expect(result.slots.first.total, Decimal.fromInt(4));
      expect(result.slots.first.itemCount, 1);
      expect(result.slots.last.total, Decimal.fromInt(7));
      expect(result.slots.last.itemCount, 1);
      final total = result.slots.fold(
        Decimal.zero,
        (sum, slot) => sum + slot.total,
      );
      expect(total, Decimal.fromInt(11));
    });
  });

  group('past year', () {
    test('includes january and december bookings', () {
      final state = _state(
        categories: [
          _category(_main),
          _category(_childA, parent: _main),
          _category(_childB, parent: _main),
        ],
        bookings: [
          _Booking(_childA, 6, date: DateTime.utc(2026, 1, 5)),
          _Booking(_childB, 8, date: DateTime.utc(2026, 12, 20)),
          _Booking(_main, 9, date: DateTime.utc(2026, 12, 31)),
        ],
      );
      final result = _trend(
        state,
        main: _main,
        scope: const AnalysisCategoryScope.all(),
        period: DateTime.utc(2026, 6, 15),
        mode: AnalysisPeriodMode.year,
      );

      expect(result.slots, hasLength(12));
      expect(result.endMonth, DateTime.utc(2026, 12, 1));
      expect(_slot(result, 2026, 1).total, Decimal.fromInt(6));
      expect(_slot(result, 2026, 1).itemCount, 1);
      expect(_slot(result, 2026, 12).total, Decimal.fromInt(17));
      expect(_slot(result, 2026, 12).itemCount, 2);
      expect(_slot(result, 2026, 6).total, Decimal.zero);
    });

    test('empty scopes keep twelve zero slots in both modes', () {
      final state = _state(
        categories: [
          _category(_main),
          _category(_childA, parent: _main),
          _category(_childB, parent: _main),
        ],
        bookings: [_Booking(_childA, 6, date: DateTime.utc(2027, 1, 10))],
      );
      final monthEmpty = _trend(
        state,
        main: _main,
        scope: AnalysisCategoryScope.subcategory(_childB),
      );
      final yearEmpty = _trend(
        state,
        main: _main,
        scope: AnalysisCategoryScope.subcategory(_childB),
        period: DateTime.utc(2027, 2, 2),
        mode: AnalysisPeriodMode.year,
      );

      for (final result in [monthEmpty, yearEmpty]) {
        expect(result.slots, hasLength(12));
        for (final slot in result.slots) {
          expect(slot.total, Decimal.zero);
          expect(slot.itemCount, 0);
        }
      }
    });
  });

  group('income', () {
    LedgerState incomeState() => _state(
      categories: [
        _category(_incomeMain, kind: CategoryKind.income),
        _category(_incomeChild, parent: _incomeMain, kind: CategoryKind.income),
      ],
      bookings: [
        _Booking(
          _incomeChild,
          6,
          income: true,
          date: DateTime.utc(2027, 1, 10),
        ),
        _Booking(_incomeMain, 9, income: true, date: DateTime.utc(2027, 1, 10)),
        _Booking(
          _incomeChild,
          8,
          income: true,
          date: DateTime.utc(2027, 5, 31),
        ),
        _Booking(_incomeMain, 4, income: true, date: DateTime.utc(2027, 5, 31)),
      ],
    );

    test('all scopes in month mode', () {
      final state = incomeState();
      ScopedTrend trend(AnalysisCategoryScope scope) => scopedTrend(
        mainBucketID: _incomeMain,
        scope: scope,
        kind: CategoryKind.income,
        period: DateTime.utc(2027, 5, 15),
        mode: AnalysisPeriodMode.month,
        today: _today,
        state: state,
        items: Accounting.analysisItems(state),
      );

      final all = trend(const AnalysisCategoryScope.all());
      final sub = trend(AnalysisCategoryScope.subcategory(_incomeChild));
      final direct = trend(const AnalysisCategoryScope.direct());

      expect(_slot(all, 2027, 1).total, Decimal.fromInt(15));
      expect(_slot(all, 2027, 1).itemCount, 2);
      expect(_slot(sub, 2027, 1).total, Decimal.fromInt(6));
      expect(_slot(sub, 2027, 1).itemCount, 1);
      expect(_slot(direct, 2027, 1).total, Decimal.fromInt(9));
      expect(_slot(direct, 2027, 1).itemCount, 1);
      expect(_slot(all, 2027, 5).total, Decimal.fromInt(12));
      expect(_slot(sub, 2027, 5).total, Decimal.fromInt(8));
      expect(_slot(direct, 2027, 5).total, Decimal.fromInt(4));
    });

    test('all scopes in year mode', () {
      final state = incomeState();
      ScopedTrend trend(AnalysisCategoryScope scope) => scopedTrend(
        mainBucketID: _incomeMain,
        scope: scope,
        kind: CategoryKind.income,
        period: DateTime.utc(2027, 8, 1),
        mode: AnalysisPeriodMode.year,
        today: _today,
        state: state,
        items: Accounting.analysisItems(state),
      );

      expect(
        _slot(trend(const AnalysisCategoryScope.all()), 2027, 1).total,
        Decimal.fromInt(15),
      );
      expect(
        _slot(
          trend(AnalysisCategoryScope.subcategory(_incomeChild)),
          2027,
          1,
        ).total,
        Decimal.fromInt(6),
      );
      expect(
        _slot(trend(const AnalysisCategoryScope.direct()), 2027, 1).total,
        Decimal.fromInt(9),
      );
    });

    test('expense scopes ignore income items', () {
      final result = _trend(
        incomeState(),
        main: _incomeMain,
        scope: const AnalysisCategoryScope.all(),
      );

      for (final slot in result.slots) {
        expect(slot.total, Decimal.zero);
        expect(slot.itemCount, 0);
      }
    });
  });

  group('isolation', () {
    test('unrelated mains do not leak', () {
      final state = _coreState();
      final main = _trend(
        state,
        main: _main,
        scope: const AnalysisCategoryScope.all(),
      );
      final other = _trend(
        state,
        main: _other,
        scope: AnalysisCategoryScope.subcategory(_otherChild),
      );

      expect(_slot(main, 2027, 1).total, Decimal.fromInt(10));
      expect(_slot(other, 2027, 1).total, Decimal.fromInt(50));
      expect(_slot(other, 2027, 1).itemCount, 1);
      expect(_slot(main, 2027, 5).total, Decimal.fromInt(31));
      expect(_slot(other, 2027, 5).total, Decimal.zero);
    });

    test('sibling subcategories do not leak', () {
      final state = _coreState();
      final subA = _trend(
        state,
        main: _main,
        scope: AnalysisCategoryScope.subcategory(_childA),
      );
      final subB = _trend(
        state,
        main: _main,
        scope: AnalysisCategoryScope.subcategory(_childB),
      );

      expect(_slot(subA, 2027, 1).total, Decimal.fromInt(2));
      expect(_slot(subB, 2027, 1).total, Decimal.fromInt(3));
      expect(_slot(subA, 2027, 5).total, Decimal.fromInt(7));
      expect(_slot(subB, 2027, 5).total, Decimal.fromInt(11));
    });
  });

  group('anchors', () {
    test('january and december periods share the year anchor', () {
      final state = _coreState();
      final january = _trend(
        state,
        main: _main,
        scope: const AnalysisCategoryScope.all(),
        period: DateTime.utc(2027, 1, 3),
        mode: AnalysisPeriodMode.year,
      );
      final december = _trend(
        state,
        main: _main,
        scope: const AnalysisCategoryScope.all(),
        period: DateTime.utc(2027, 12, 25),
        mode: AnalysisPeriodMode.year,
      );

      expect(january.endMonth, DateTime.utc(2027, 12, 1));
      expect(december, january);
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

    test('december anchoring succeeds in the current year', () {
      final result = _trend(
        _coreState(),
        main: _main,
        scope: const AnalysisCategoryScope.all(),
        period: DateTime.utc(2027, 12, 25),
        mode: AnalysisPeriodMode.year,
      );

      expect(result.endMonth, DateTime.utc(2027, 12, 1));
      expect(result.slots, hasLength(12));
    });

    test('local non-midnight period shares the midnight anchor', () {
      final state = _coreState();
      ScopedTrend trend(DateTime period, AnalysisPeriodMode mode) => _trend(
        state,
        main: _main,
        scope: const AnalysisCategoryScope.all(),
        period: period,
        mode: mode,
      );

      final monthMidnight = trend(
        DateTime.utc(2027, 5, 15),
        AnalysisPeriodMode.month,
      );
      final monthLocal = trend(
        DateTime(2027, 5, 15, 13, 30),
        AnalysisPeriodMode.month,
      );
      final yearMidnight = trend(
        DateTime.utc(2027, 3, 20),
        AnalysisPeriodMode.year,
      );
      final yearLocal = trend(
        DateTime(2027, 3, 20, 8, 45),
        AnalysisPeriodMode.year,
      );

      expect(monthLocal.endMonth, DateTime.utc(2027, 5, 1));
      expect(monthLocal, monthMidnight);
      expect(yearLocal.endMonth, DateTime.utc(2027, 12, 1));
      expect(yearLocal, yearMidnight);
    });
  });

  group('scope matching', () {
    test('uppercase ids normalise', () {
      const upperMain = 'ABCDEF12-ABCD-4000-8000-ABCDEFABCDEF';
      const upperChild = '12345678-ABCD-4000-8000-ABCDEFABCDEF';
      final state = _state(
        categories: [
          _category(upperMain),
          _category(upperChild, parent: upperMain),
        ],
        bookings: [
          _Booking(upperChild, 6, date: DateTime.utc(2027, 1, 10)),
          _Booking(upperMain, 9, date: DateTime.utc(2027, 1, 10)),
        ],
      );
      ScopedTrend trend(String? main, AnalysisCategoryScope scope) =>
          scopedTrend(
            mainBucketID: main,
            scope: scope,
            kind: CategoryKind.expense,
            period: DateTime.utc(2027, 5, 15),
            mode: AnalysisPeriodMode.month,
            today: _today,
            state: state,
            items: Accounting.analysisItems(state),
          );

      final lowerMain = upperMain.toLowerCase();
      final lowerChild = upperChild.toLowerCase();
      final upperAll = trend(upperMain, const AnalysisCategoryScope.all());
      final lowerAll = trend(lowerMain, const AnalysisCategoryScope.all());
      final upperDirect = trend(
        upperMain,
        const AnalysisCategoryScope.direct(),
      );
      final lowerDirect = trend(
        lowerMain,
        const AnalysisCategoryScope.direct(),
      );
      final upperSub = trend(
        upperMain,
        AnalysisCategoryScope.subcategory(upperChild),
      );
      final lowerSub = trend(
        lowerMain,
        AnalysisCategoryScope.subcategory(lowerChild),
      );

      expect(_slot(upperAll, 2027, 1).total, Decimal.fromInt(15));
      expect(_slot(upperAll, 2027, 1).itemCount, 2);
      expect(upperAll, lowerAll);
      expect(upperAll.hashCode, lowerAll.hashCode);
      expect(_slot(upperDirect, 2027, 1).total, Decimal.fromInt(9));
      expect(_slot(upperDirect, 2027, 1).itemCount, 1);
      expect(upperDirect, lowerDirect);
      expect(upperDirect.hashCode, lowerDirect.hashCode);
      expect(_slot(upperSub, 2027, 1).total, Decimal.fromInt(6));
      expect(_slot(upperSub, 2027, 1).itemCount, 1);
      expect(upperSub, lowerSub);
      expect(upperSub.hashCode, lowerSub.hashCode);
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
      expect(() => trend(_main, _id(99)), throwsArgumentError);
      expect(() => trend(_main, _main), throwsArgumentError);
      expect(() => trend(_childB, _childA), throwsArgumentError);
    });

    test('null main works for all and direct', () {
      final state = _state(
        categories: [_category(_main)],
        bookings: [
          _Booking(null, 5, date: DateTime.utc(2027, 1, 10)),
          _Booking(_main, 20, date: DateTime.utc(2027, 1, 10)),
        ],
      );
      final all = _trend(
        state,
        main: null,
        scope: const AnalysisCategoryScope.all(),
      );
      final direct = _trend(
        state,
        main: null,
        scope: const AnalysisCategoryScope.direct(),
      );

      expect(_slot(all, 2027, 1).total, Decimal.fromInt(5));
      expect(_slot(all, 2027, 1).itemCount, 1);
      expect(_slot(direct, 2027, 1).total, Decimal.fromInt(5));
      expect(_slot(direct, 2027, 1).itemCount, 1);
    });

    test('unknown main yields twelve zero slots for all and direct', () {
      final state = _coreState();
      final all = _trend(
        state,
        main: _id(99),
        scope: const AnalysisCategoryScope.all(),
      );
      final direct = _trend(
        state,
        main: _id(99),
        scope: const AnalysisCategoryScope.direct(),
      );

      for (final result in [all, direct]) {
        expect(result.slots, hasLength(12));
        expect(result.mainBucketID, _id(99));
        for (final slot in result.slots) {
          expect(slot.total, Decimal.zero);
          expect(slot.itemCount, 0);
        }
      }
    });

    test('synthetic main works for all and direct', () {
      final state = _state(
        categories: [_category(_main)],
        bookings: [_Booking(_main, 20, date: DateTime.utc(2027, 1, 10))],
        syntheticTransfer: 20,
        transferDate: DateTime.utc(2027, 1, 12),
      );
      final all = _trend(
        state,
        main: _syntheticID,
        scope: const AnalysisCategoryScope.all(),
      );
      final direct = _trend(
        state,
        main: _syntheticID,
        scope: const AnalysisCategoryScope.direct(),
      );

      expect(_slot(all, 2027, 1).total, Decimal.fromInt(20));
      expect(_slot(all, 2027, 1).itemCount, 1);
      expect(_slot(direct, 2027, 1).total, Decimal.fromInt(20));
      expect(_slot(direct, 2027, 1).itemCount, 1);
    });
  });

  group('value contracts', () {
    test('independent equal scopes are equal', () {
      final first = AnalysisCategoryScope.subcategory(_childA);
      final second = AnalysisCategoryScope.subcategory(_childA.toUpperCase());

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(
        const AnalysisCategoryScope.all(),
        const AnalysisCategoryScope.all(),
      );
      expect(
        const AnalysisCategoryScope.direct(),
        const AnalysisCategoryScope.direct(),
      );
    });

    test('scopes differ by variant and id', () {
      final sub = AnalysisCategoryScope.subcategory(_childA);

      expect(sub, isNot(AnalysisCategoryScope.subcategory(_childB)));
      expect(sub, isNot(const AnalysisCategoryScope.all()));
      expect(sub, isNot(const AnalysisCategoryScope.direct()));
      expect(
        const AnalysisCategoryScope.all(),
        isNot(const AnalysisCategoryScope.direct()),
      );
    });

    test('independent equal trends are equal', () {
      final first = _trend(
        _coreState(),
        main: _main,
        scope: const AnalysisCategoryScope.all(),
      );
      final second = _trend(
        _coreState(),
        main: _main,
        scope: const AnalysisCategoryScope.all(),
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });

    test('trends differ by one metadata field at a time', () {
      final base = _trend(
        _coreState(),
        main: _main,
        scope: const AnalysisCategoryScope.all(),
      );
      ScopedTrend copyWith({
        AnalysisPeriodMode? mode,
        DateTime? endMonth,
        CategoryKind? kind,
        String? mainBucketID,
        AnalysisCategoryScope? scope,
      }) => ScopedTrend(
        mode: mode ?? base.mode,
        endMonth: endMonth ?? base.endMonth,
        kind: kind ?? base.kind,
        mainBucketID: mainBucketID ?? base.mainBucketID,
        scope: scope ?? base.scope,
        slots: base.slots,
      );

      expect(copyWith(mode: AnalysisPeriodMode.year), isNot(base));
      expect(copyWith(endMonth: DateTime.utc(2027, 4, 1)), isNot(base));
      expect(copyWith(kind: CategoryKind.income), isNot(base));
      expect(copyWith(mainBucketID: _other), isNot(base));
      expect(
        copyWith(scope: const AnalysisCategoryScope.direct()),
        isNot(base),
      );
    });

    test('trends differ by slot', () {
      final base = _trend(
        _coreState(),
        main: _main,
        scope: const AnalysisCategoryScope.all(),
      );

      expect(
        base,
        isNot(
          ScopedTrend(
            mode: base.mode,
            endMonth: base.endMonth,
            kind: base.kind,
            mainBucketID: base.mainBucketID,
            scope: base.scope,
            slots: [
              ...base.slots.skip(1),
              MonthSlot(
                month: DateTime.utc(2027, 5, 1),
                window: monthWindow(DateTime.utc(2027, 5, 1)),
                total: Decimal.fromInt(999),
                itemCount: 1,
              ),
            ],
          ),
        ),
      );
    });

    test('the returned slot list rejects mutation', () {
      final result = _trend(
        _coreState(),
        main: _main,
        scope: const AnalysisCategoryScope.all(),
      );

      expect(
        () => result.slots.add(
          MonthSlot(
            month: DateTime.utc(2027, 5, 1),
            window: monthWindow(DateTime.utc(2027, 5, 1)),
            total: Decimal.one,
            itemCount: 1,
          ),
        ),
        throwsUnsupportedError,
      );
    });
  });
}
