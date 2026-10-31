import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  const id = '00000000-0000-4000-8000-000000000001';
  const categoryID = '00000000-0000-4000-8000-000000000002';

  Budget budget({
    String? budgetID = id,
    String? category = categoryID,
    int limit = 100,
  }) =>
      Budget(id: budgetID, categoryID: category, limit: Decimal.fromInt(limit));

  test('equal id, category and limit compare equal with equal hashes', () {
    expect(budget(), budget());
    expect(budget().hashCode, budget().hashCode);
  });

  test('a different id makes budgets unequal', () {
    expect(
      budget(budgetID: '00000000-0000-4000-8000-000000000003'),
      isNot(budget()),
    );
  });

  test('a different category makes budgets unequal', () {
    expect(budget(category: null), isNot(budget()));
  });

  test('a different limit makes budgets unequal', () {
    expect(budget(limit: 200), isNot(budget()));
  });

  test('a non-budget is unequal', () {
    expect(budget() == Object(), isFalse);
  });

  test('the id is normalized to lowercase', () {
    expect(budget(budgetID: id.toUpperCase()).id, id);
  });

  test('a missing id is generated', () {
    expect(budget(budgetID: null).id, isNotEmpty);
  });

  test('toString names id, category and limit', () {
    expect(budget().toString(), 'Budget($id, $categoryID, 100)');
  });
}
