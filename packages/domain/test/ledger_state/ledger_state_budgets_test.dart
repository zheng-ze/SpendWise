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

  Budget createBudget(LedgerState state, [String? forCategory]) {
    final changes = state.addBudget(forCategory, Decimal.fromInt(100));
    return (changes.single as UpsertBudget).budget;
  }

  group('addBudget', () {
    test('creates a budget on an active category', () {
      final state = seeded();

      final changes = state.addBudget(categoryID, Decimal.fromInt(100));

      expect(changes, hasLength(1));
      final change = changes.single as UpsertBudget;
      expect(change.budget.categoryID, categoryID);
      expect(change.budget.limit, Decimal.fromInt(100));
      expect(state.budgets[change.budget.id], change.budget);
    });

    test('creates an overall budget when categoryID is null', () {
      final state = seeded();

      final change = state.addBudget(null, Decimal.fromInt(100)).single;

      expect((change as UpsertBudget).budget.categoryID, isNull);
    });

    test('rejects an unknown category', () {
      final state = seeded();

      expect(
        () => state.addBudget(uuid(9), Decimal.fromInt(100)),
        throwsA(isA<UnknownCategory>()),
      );
      expect(state.budgets, isEmpty);
    });

    test('rejects an inactive category', () {
      final state = seeded();
      state.deleteCategory(categoryID);

      expect(
        () => state.addBudget(categoryID, Decimal.fromInt(100)),
        throwsA(isA<InactiveReference>()),
      );
      expect(state.budgets, isEmpty);
    });

    test('rejects a duplicate category', () {
      final state = seeded();
      createBudget(state, categoryID);

      expect(
        () => state.addBudget(categoryID, Decimal.fromInt(50)),
        throwsA(isA<CategoryAlreadyBudgeted>()),
      );
      expect(state.budgets, hasLength(1));
    });

    test('rejects a duplicate null category', () {
      final state = seeded();
      createBudget(state);

      expect(
        () => state.addBudget(null, Decimal.fromInt(50)),
        throwsA(isA<CategoryAlreadyBudgeted>()),
      );
      expect(state.budgets, hasLength(1));
    });

    test('rejects a zero limit', () {
      final state = seeded();

      expect(
        () => state.addBudget(categoryID, Decimal.zero),
        throwsA(isA<ZeroAmount>()),
      );
      expect(state.budgets, isEmpty);
    });

    test('rejects a negative limit', () {
      final state = seeded();

      expect(
        () => state.addBudget(categoryID, Decimal.fromInt(-1)),
        throwsA(isA<ZeroAmount>()),
      );
      expect(state.budgets, isEmpty);
    });

    test('reports the category error before the limit error', () {
      final state = seeded();

      expect(
        () => state.addBudget(uuid(9), Decimal.zero),
        throwsA(isA<UnknownCategory>()),
      );
    });

    test('reports the duplicate error before the limit error', () {
      final state = seeded();
      createBudget(state, categoryID);

      expect(
        () => state.addBudget(categoryID, Decimal.zero),
        throwsA(isA<CategoryAlreadyBudgeted>()),
      );
    });
  });

  group('updateBudgetLimit', () {
    test('replaces the limit and keeps id and category', () {
      final state = seeded();
      final created = createBudget(state, categoryID);

      final changes = state.updateBudgetLimit(created.id, Decimal.fromInt(200));

      final updated = (changes.single as UpsertBudget).budget;
      expect(updated.id, created.id);
      expect(updated.categoryID, categoryID);
      expect(updated.limit, Decimal.fromInt(200));
      expect(state.budgets[created.id], updated);
      expect(state.budgets, hasLength(1));
    });

    test('normalizes a raw uppercase budget id', () {
      final state = seeded();
      final created = createBudget(state, categoryID);

      final changes = state.updateBudgetLimit(
        created.id.toUpperCase(),
        Decimal.fromInt(200),
      );

      final updated = (changes.single as UpsertBudget).budget;
      expect(updated.id, created.id);
      expect(state.budgets[created.id]?.limit, Decimal.fromInt(200));
    });

    test('rejects an unknown budget id', () {
      final state = seeded();

      expect(
        () => state.updateBudgetLimit(uuid(9), Decimal.fromInt(200)),
        throwsA(isA<UnknownBudget>()),
      );
    });

    test('rejects a zero limit and keeps the stored limit', () {
      final state = seeded();
      final created = createBudget(state, categoryID);

      expect(
        () => state.updateBudgetLimit(created.id, Decimal.zero),
        throwsA(isA<ZeroAmount>()),
      );
      expect(state.budgets[created.id]?.limit, Decimal.fromInt(100));
    });

    test('rejects a negative limit', () {
      final state = seeded();
      final created = createBudget(state, categoryID);

      expect(
        () => state.updateBudgetLimit(created.id, Decimal.fromInt(-5)),
        throwsA(isA<ZeroAmount>()),
      );
    });

    test('reports the unknown budget before the limit error', () {
      final state = seeded();

      expect(
        () => state.updateBudgetLimit(uuid(9), Decimal.zero),
        throwsA(isA<UnknownBudget>()),
      );
    });
  });

  group('deleteBudget', () {
    test('removes an existing budget', () {
      final state = seeded();
      final created =
          (state.addBudget(categoryID, Decimal.fromInt(100)).single
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
