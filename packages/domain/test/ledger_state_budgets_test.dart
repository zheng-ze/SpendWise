import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  String uuid(int n) =>
      '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';

  final categoryID = uuid(1);
  final otherCategoryID = uuid(2);

  TransactionCategory category({
    String? id,
    LifecycleState lifecycle = LifecycleState.active,
  }) => TransactionCategory(
    id: id ?? categoryID,
    name: 'Rent',
    kind: CategoryKind.expense,
    colorHex: '#888888',
    includeInAnalysis: true,
    parentID: null,
    symbol: 'tag',
    lifecycle: lifecycle,
  );

  LedgerState seeded() {
    final state = LedgerState();
    state.addCategory(category());
    state.addCategory(category(id: otherCategoryID));
    return state;
  }

  group('addBudget validation', () {
    test('creates a budget on an active category', () {
      final state = seeded();

      final changes = state.addBudget(
        categoryID,
        Decimal.fromInt(100),
        RolloverMode.none,
      );

      expect(changes, hasLength(1));
      final change = changes.single as UpsertBudget;
      expect(change.budget.categoryID, categoryID);
      expect(state.budgets[change.budget.id], isNotNull);
    });

    test('creates an overall budget when categoryID is null', () {
      final state = seeded();

      final changes = state.addBudget(
        null,
        Decimal.fromInt(100),
        RolloverMode.none,
      );

      final change = changes.single as UpsertBudget;
      expect(change.budget.categoryID, isNull);
    });

    test('rejects an unknown category', () {
      final state = seeded();

      expect(
        () => state.addBudget(uuid(9), Decimal.fromInt(100), RolloverMode.none),
        throwsA(isA<UnknownCategory>()),
      );
      expect(state.budgets, isEmpty);
    });

    test('rejects an inactive category', () {
      final state = seeded();
      state.deleteCategory(categoryID);

      expect(
        () => state.addBudget(
          categoryID,
          Decimal.fromInt(100),
          RolloverMode.none,
        ),
        throwsA(isA<InactiveReference>()),
      );
      expect(state.budgets, isEmpty);
    });

    test('rejects a duplicate category', () {
      final state = seeded();
      state.addBudget(categoryID, Decimal.fromInt(100), RolloverMode.none);

      expect(
        () =>
            state.addBudget(categoryID, Decimal.fromInt(50), RolloverMode.none),
        throwsA(isA<CategoryAlreadyBudgeted>()),
      );
      expect(state.budgets, hasLength(1));
    });

    test('rejects a duplicate null category', () {
      final state = seeded();
      state.addBudget(null, Decimal.fromInt(100), RolloverMode.none);

      expect(
        () => state.addBudget(null, Decimal.fromInt(50), RolloverMode.none),
        throwsA(isA<CategoryAlreadyBudgeted>()),
      );
      expect(state.budgets, hasLength(1));
    });

    test('rejects a zero limit', () {
      final state = seeded();

      expect(
        () => state.addBudget(categoryID, Decimal.zero, RolloverMode.none),
        throwsA(isA<ZeroAmount>()),
      );
      expect(state.budgets, isEmpty);
    });

    test('rejects a negative limit', () {
      final state = seeded();

      expect(
        () =>
            state.addBudget(categoryID, Decimal.fromInt(-1), RolloverMode.none),
        throwsA(isA<ZeroAmount>()),
      );
      expect(state.budgets, isEmpty);
    });

    test('rejects a negative carryCap', () {
      final state = seeded();

      expect(
        () => state.addBudget(
          categoryID,
          Decimal.fromInt(100),
          RolloverMode.positiveOnly,
          carryCap: Decimal.fromInt(-1),
        ),
        throwsA(isA<CarryCapInvalid>()),
      );
      expect(state.budgets, isEmpty);
    });

    test('rejects a zero carryCap under positiveOnly', () {
      final state = seeded();

      expect(
        () => state.addBudget(
          categoryID,
          Decimal.fromInt(100),
          RolloverMode.positiveOnly,
          carryCap: Decimal.zero,
        ),
        throwsA(isA<CarryCapInvalid>()),
      );
      expect(state.budgets, isEmpty);
    });

    test('rejects a zero carryCap under both', () {
      final state = seeded();

      expect(
        () => state.addBudget(
          categoryID,
          Decimal.fromInt(100),
          RolloverMode.both,
          carryCap: Decimal.zero,
        ),
        throwsA(isA<CarryCapInvalid>()),
      );
      expect(state.budgets, isEmpty);
    });

    test('rejects a non-null carryCap under none', () {
      final state = seeded();

      expect(
        () => state.addBudget(
          categoryID,
          Decimal.fromInt(100),
          RolloverMode.none,
          carryCap: Decimal.fromInt(50),
        ),
        throwsA(isA<CarryCapInvalid>()),
      );
      expect(state.budgets, isEmpty);
    });

    test('accepts a positive carryCap under rollover', () {
      final state = seeded();

      final changes = state.addBudget(
        categoryID,
        Decimal.fromInt(100),
        RolloverMode.both,
        carryCap: Decimal.fromInt(50),
      );

      final change = changes.single as UpsertBudget;
      expect(change.budget.carryCap, Decimal.fromInt(50));
    });
  });

  group('updateBudgetAmount', () {
    test('appends a new default event', () {
      final state = seeded();
      final created =
          (state
                      .addBudget(
                        categoryID,
                        Decimal.fromInt(100),
                        RolloverMode.none,
                      )
                      .single
                  as UpsertBudget)
              .budget;

      final changes = state.updateBudgetAmount(
        created.id,
        Decimal.fromInt(200),
        const YearMonth(2026, 6),
      );

      final updated = (changes.single as UpsertBudget).budget;
      expect(updated.limitEvents, hasLength(2));
      expect(
        effectiveLimit(updated, const YearMonth(2026, 6)),
        Decimal.fromInt(200),
      );
      expect(
        effectiveLimit(updated, const YearMonth(2026, 1)),
        Decimal.fromInt(100),
      );
    });

    test('rejects an unknown budget id', () {
      final state = seeded();

      expect(
        () => state.updateBudgetAmount(
          uuid(9),
          Decimal.fromInt(200),
          const YearMonth(2026, 6),
        ),
        throwsA(isA<UnknownBudget>()),
      );
    });

    test('rejects a non-positive amount', () {
      final state = seeded();
      final created =
          (state
                      .addBudget(
                        categoryID,
                        Decimal.fromInt(100),
                        RolloverMode.none,
                      )
                      .single
                  as UpsertBudget)
              .budget;

      expect(
        () => state.updateBudgetAmount(
          created.id,
          Decimal.zero,
          const YearMonth(2026, 6),
        ),
        throwsA(isA<ZeroAmount>()),
      );
    });
  });

  group('setBudgetMonthOverride', () {
    test('appends an override event that wins for its month', () {
      final state = seeded();
      final created =
          (state
                      .addBudget(
                        categoryID,
                        Decimal.fromInt(100),
                        RolloverMode.none,
                      )
                      .single
                  as UpsertBudget)
              .budget;

      final changes = state.setBudgetMonthOverride(
        created.id,
        const YearMonth(2026, 6),
        Decimal.fromInt(999),
      );

      final updated = (changes.single as UpsertBudget).budget;
      expect(
        effectiveLimit(updated, const YearMonth(2026, 6)),
        Decimal.fromInt(999),
      );
      expect(
        effectiveLimit(updated, const YearMonth(2026, 7)),
        Decimal.fromInt(100),
      );
    });

    test('a new override on the same month replaces the previous one', () {
      final state = seeded();
      final created =
          (state
                      .addBudget(
                        categoryID,
                        Decimal.fromInt(100),
                        RolloverMode.none,
                      )
                      .single
                  as UpsertBudget)
              .budget;
      state.setBudgetMonthOverride(
        created.id,
        const YearMonth(2026, 6),
        Decimal.fromInt(500),
      );

      final changes = state.setBudgetMonthOverride(
        created.id,
        const YearMonth(2026, 6),
        Decimal.fromInt(700),
      );

      final updated = (changes.single as UpsertBudget).budget;
      expect(
        effectiveLimit(updated, const YearMonth(2026, 6)),
        Decimal.fromInt(700),
      );
    });

    test('rejects an unknown budget id', () {
      final state = seeded();

      expect(
        () => state.setBudgetMonthOverride(
          uuid(9),
          const YearMonth(2026, 6),
          Decimal.fromInt(100),
        ),
        throwsA(isA<UnknownBudget>()),
      );
    });
  });

  group('deleteBudget', () {
    test('removes an existing budget', () {
      final state = seeded();
      final created =
          (state
                      .addBudget(
                        categoryID,
                        Decimal.fromInt(100),
                        RolloverMode.none,
                      )
                      .single
                  as UpsertBudget)
              .budget;

      final changes = state.deleteBudget(created.id);

      expect(changes, [DeleteBudget(created.id)]);
      expect(state.budgets, isEmpty);
    });

    test('is a no-op on a missing id', () {
      final state = seeded();

      final changes = state.deleteBudget(uuid(9));

      expect(changes, isEmpty);
    });
  });
}
