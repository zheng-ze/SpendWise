import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ledger/analysis/budgets/budget_overview.dart';

const _foodID = 'a0000000-0000-0000-0000-00000000000f';
const _lookalikeID = 'a0000000-0000-0000-0000-0000000000d4';
const _hawkerID = 'a0000000-0000-0000-0000-0000000000a1';
const _transportID = 'a0000000-0000-0000-0000-0000000000b2';
const _month = YearMonth(2026, 10);
final _october3 = DateTime.utc(2026, 10, 3);

Decimal dec(String value) => Decimal.parse(value);

TransactionCategory category(String id, String name, {String? parentID}) =>
    TransactionCategory(
      id: id,
      name: name,
      kind: CategoryKind.expense,
      colorHex: '#00AA00',
      includeInAnalysis: true,
      parentID: parentID,
      symbol: 'restaurant',
    );

Budget budget(String? categoryID, String limit, {String? id}) => Budget(
  id: id,
  categoryID: categoryID,
  limitEvents: [
    LimitEvent(
      effectiveFromMonth: null,
      value: dec(limit),
      kind: LimitEventKind.defaultLimit,
    ),
  ],
  createdAtMonth: _month,
);

LedgerState ledgerWith(List<Budget> budgets) {
  final categories = [
    category(_foodID, 'Food'),
    category(_hawkerID, 'Hawker', parentID: _foodID),
    category(_transportID, 'Transport'),
    category(_lookalikeID, ' food '),
  ];
  return LedgerState(
    categories: {for (final c in categories) c.id: c},
    budgets: {for (final b in budgets) b.id: b},
  );
}

AnalysisItem spend(String? bucketID, String amount, {int day = 2}) =>
    AnalysisItem(
      bucketID: bucketID,
      amount: dec(amount),
      date: DateTime.utc(2026, 10, day),
      kind: CategoryKind.expense,
    );

BudgetsOverview overview(
  List<Budget> budgets, {
  List<AnalysisItem> items = const [],
  DateTime? today,
  YearMonth month = _month,
}) => budgetsOverview(
  state: ledgerWith(budgets),
  items: items,
  month: month,
  today: today ?? _october3,
);

void main() {
  group('All spending cap', () {
    test('the unscoped budget limit wins over category budgets', () {
      final result = overview([
        budget(null, '500', id: 'b0000000-0000-0000-0000-000000000001'),
        budget(_foodID, '100'),
        budget(_transportID, '200'),
      ]);

      expect(result.allSpending.cap, dec('500'));
      expect(
        result.allSpending.capBudgetID,
        'b0000000-0000-0000-0000-000000000001',
      );
    });

    test('without an unscoped budget it sums the top level budgets', () {
      final result = overview([
        budget(_foodID, '100'),
        budget(_transportID, '60'),
      ]);

      expect(result.allSpending.cap, dec('160'));
      expect(result.allSpending.capBudgetID, isNull);
    });

    test('a configured parent excludes its child from the cap', () {
      final result = overview([
        budget(_foodID, '100'),
        budget(_hawkerID, '40'),
        budget(_transportID, '60'),
      ]);

      expect(result.allSpending.cap, dec('160'));
    });

    test('a month override changes the cap for that month only', () {
      final overridden = Budget(
        categoryID: null,
        limitEvents: [
          LimitEvent(
            effectiveFromMonth: null,
            value: dec('500'),
            kind: LimitEventKind.defaultLimit,
          ),
          LimitEvent(
            effectiveFromMonth: _month,
            value: dec('650'),
            kind: LimitEventKind.override,
          ),
        ],
        createdAtMonth: _month,
      );

      final october = overview([overridden]);
      final november = overview([overridden], month: const YearMonth(2026, 11));

      expect(october.allSpending.cap, dec('650'));
      expect(november.allSpending.cap, dec('500'));
    });

    test('an orphan subcategory budget counts toward the cap', () {
      final result = overview([
        budget(_hawkerID, '40'),
        budget(_transportID, '60'),
      ]);

      expect(result.allSpending.cap, dec('100'));
    });

    test('a budget without a default event fails the read', () {
      final bare = Budget(
        categoryID: _foodID,
        limitEvents: const [],
        createdAtMonth: _month,
      );

      expect(() => overview([bare]), throwsStateError);
    });

    test('no budgets leaves the cap and allowance absent', () {
      final result = overview([], items: [spend(null, '12')]);

      expect(result.hasBudgets, isFalse);
      expect(result.allSpending.cap, isNull);
      expect(result.allSpending.remaining, isNull);
      expect(result.allSpending.dailyAllowance, isNull);
      expect(result.allSpending.spent, dec('12'));
    });

    test('a zero limit fails the read instead of imposing a ratio', () {
      expect(() => overview([budget(_foodID, '0')]), throwsStateError);
    });
  });

  group('Spent so far', () {
    test('counts every expense bucket, not the sum of overlapping rows', () {
      final items = [
        spend(_foodID, '10'),
        spend(_hawkerID, '20'),
        spend(null, '5'),
        spend(_transportID, '7'),
        spend('transfer-expense:card', '3'),
        AnalysisItem(
          bucketID: _foodID,
          amount: dec('999'),
          date: DateTime.utc(2026, 10, 2),
          kind: CategoryKind.income,
        ),
        AnalysisItem(
          bucketID: _foodID,
          amount: dec('400'),
          date: DateTime.utc(2026, 9, 30),
          kind: CategoryKind.expense,
        ),
      ];

      final result = overview([
        budget(_foodID, '100'),
        budget(_hawkerID, '40'),
      ], items: items);

      final rowTotal = result.categoryBudgets.fold(
        Decimal.zero,
        (sum, row) => sum + row.spend,
      );
      expect(result.allSpending.spent, dec('45'));
      expect(rowTotal, dec('50'));
    });

    test('an empty month spends zero', () {
      final result = overview([budget(_foodID, '100')]);

      expect(result.allSpending.spent, Decimal.zero);
      expect(result.allSpending.remaining, dec('100'));
    });

    test('remaining stays signed when over the cap', () {
      final result = overview(
        [budget(null, '100')],
        items: [spend(_foodID, '130')],
      );

      expect(result.allSpending.remaining, dec('-30'));
    });
  });

  group('Category ranking', () {
    List<String> order(BudgetsOverview result) => [
      for (final row in result.categoryBudgets) row.name,
    ];

    test('orders by used share, highest first', () {
      final result = overview(
        [
          budget(_foodID, '100'),
          budget(_transportID, '100'),
          budget(_hawkerID, '100'),
        ],
        items: [
          spend(_foodID, '10'),
          spend(_transportID, '50'),
          spend(_hawkerID, '30'),
        ],
      );

      expect(order(result), ['Transport', 'Food', 'Hawker']);
    });

    test('equal ratios rank by name even when absolute spend differs', () {
      final result = overview(
        [budget(_transportID, '200'), budget(_foodID, '100')],
        items: [spend(_transportID, '100'), spend(_foodID, '50')],
      );

      expect(order(result), ['Food', 'Transport']);
    });

    test(
      'near equal ratios with the same displayed percent keep exact order',
      () {
        final result = overview(
          [budget(_foodID, '3000'), budget(_transportID, '3000')],
          items: [spend(_foodID, '1000'), spend(_transportID, '1000.01')],
        );

        expect(order(result), ['Transport', 'Food']);
      },
    );

    test('exact ties fall back to the normalized name, then the budget id', () {
      final first = budget(
        _foodID,
        '100',
        id: 'B0000000-0000-0000-0000-00000000000B',
      );
      final second = budget(
        _lookalikeID,
        '100',
        id: 'a0000000-0000-0000-0000-00000000000a',
      );
      final last = budget(_transportID, '100');

      final forward = overview([first, second, last]);
      final reverse = overview([last, second, first]);

      expect(order(forward), [' food ', 'Food', 'Transport']);
      expect(order(reverse), order(forward));
    });

    test('an over limit row keeps its real ratio above the rest', () {
      final result = overview(
        [budget(_foodID, '100'), budget(_transportID, '100')],
        items: [spend(_foodID, '99'), spend(_transportID, '150')],
      );

      expect(order(result), ['Transport', 'Food']);
      expect(result.categoryBudgets.first.remaining, dec('-50'));
      expect(result.categoryBudgets.first.utilizationRatio, dec('1.5'));
    });

    test('a budget on a missing category fails the read', () {
      final orphan = budget('a0000000-0000-0000-0000-0000000000ee', '100');

      expect(() => overview([orphan]), throwsStateError);
    });
  });

  group('Daily pace', () {
    Decimal? allowance({
      required DateTime today,
      YearMonth month = _month,
      String cap = '1200',
      String spent = '167.40',
    }) {
      final result = overview(
        [budget(null, cap)],
        items: [
          AnalysisItem(
            bucketID: null,
            amount: dec(spent),
            date: DateTime.utc(month.year, month.month, 2),
            kind: CategoryKind.expense,
          ),
        ],
        today: today,
        month: month,
      );
      return result.allSpending.dailyAllowance;
    }

    test('divides the remaining allowance over the days after today', () {
      final value = allowance(today: _october3);

      expect(value?.round(scale: 2), dec('36.88'));
      expect(value, isNot(dec('36.88')));
    });

    test('an over cap month allows nothing more', () {
      expect(allowance(today: _october3, spent: '1300'), Decimal.zero);
    });

    test('the final day has no forward allowance', () {
      expect(allowance(today: DateTime.utc(2026, 10, 31)), isNull);
    });

    test('a past selected month omits the allowance', () {
      expect(
        allowance(today: _october3, month: const YearMonth(2026, 9)),
        isNull,
      );
    });
  });
}
