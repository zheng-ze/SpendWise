import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  String uuid(int n) =>
      '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';

  final categoryID = uuid(1);
  final childCategoryID = uuid(2);
  final unrelatedCategoryID = uuid(3);

  TransactionCategory category({required String id, String? parentID}) =>
      TransactionCategory(
        id: id,
        name: 'cat',
        kind: CategoryKind.expense,
        colorHex: '#888888',
        includeInAnalysis: true,
        parentID: parentID,
        symbol: 'tag',
      );

  LedgerState seeded() {
    final state = LedgerState();
    state.addCategory(category(id: categoryID));
    state.addCategory(category(id: childCategoryID, parentID: categoryID));
    state.addCategory(category(id: unrelatedCategoryID));
    return state;
  }

  test('deleting a budgeted category removes the budget', () {
    final state = seeded();
    final budget =
        (state
                    .addBudget(
                      categoryID,
                      Decimal.fromInt(100),
                      RolloverMode.none,
                    )
                    .single
                as UpsertBudget)
            .budget;

    state.deleteCategory(categoryID);
    final changes = state.purgeCategory(categoryID);

    expect(changes, contains(DeleteBudget(budget.id)));
    expect(state.budgets, isEmpty);
  });

  test('deleting a budgeted child leaves the parent budget intact', () {
    final state = seeded();
    final budget =
        (state
                    .addBudget(
                      categoryID,
                      Decimal.fromInt(100),
                      RolloverMode.none,
                    )
                    .single
                as UpsertBudget)
            .budget;

    state.deleteCategory(childCategoryID);
    state.purgeCategory(childCategoryID);

    expect(state.budgets[budget.id], isNotNull);
  });

  test(
    'deleting an unrelated category leaves an existing budget untouched',
    () {
      final state = seeded();
      final budget =
          (state
                      .addBudget(
                        categoryID,
                        Decimal.fromInt(100),
                        RolloverMode.none,
                      )
                      .single
                  as UpsertBudget)
              .budget;

      state.deleteCategory(unrelatedCategoryID);
      state.purgeCategory(unrelatedCategoryID);

      expect(state.budgets[budget.id], budget);
    },
  );
}
