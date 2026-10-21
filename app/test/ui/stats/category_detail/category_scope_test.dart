import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ui/stats/category_detail/category_scope.dart';

void main() {
  const foodID = 'a0000000-0000-0000-0000-000000000001';
  const hawkerID = 'a0000000-0000-0000-0000-000000000002';
  const cafeID = 'a0000000-0000-0000-0000-000000000003';
  const transportID = 'a0000000-0000-0000-0000-000000000004';

  final state = LedgerState(
    categories: {
      foodID: TransactionCategory(
        id: foodID,
        name: 'Food',
        kind: CategoryKind.expense,
        colorHex: '#FF0000',
        includeInAnalysis: true,
        parentID: null,
        symbol: 'restaurant',
      ),
      hawkerID: TransactionCategory(
        id: hawkerID,
        name: 'Hawker',
        kind: CategoryKind.expense,
        colorHex: '#00FF00',
        includeInAnalysis: true,
        parentID: foodID,
        symbol: 'ramen_dining',
      ),
      cafeID: TransactionCategory(
        id: cafeID,
        name: 'Cafe',
        kind: CategoryKind.expense,
        colorHex: '#00FFFF',
        includeInAnalysis: true,
        parentID: foodID,
        symbol: 'local_cafe',
      ),
      transportID: TransactionCategory(
        id: transportID,
        name: 'Transport',
        kind: CategoryKind.expense,
        colorHex: '#0000FF',
        includeInAnalysis: true,
        parentID: null,
        symbol: 'directions_bus',
      ),
    },
  );

  test('all scope matches the main category and children only', () {
    final result = matchingCategoryIDs(foodID, const AllScope(), state);

    expect(result, {foodID, hawkerID, cafeID});
    expect(result.contains(transportID), false);
  });

  test('sub scope matches only the given subcategory id', () {
    final result = matchingCategoryIDs(foodID, const SubScope(hawkerID), state);

    expect(result, {hawkerID});
  });

  test('sub scope with the null bucket matches only uncategorized', () {
    final result = matchingCategoryIDs(foodID, const SubScope(null), state);

    expect(result, {null});
  });

  test('direct scope matches only the parent category', () {
    final result = matchingCategoryIDs(foodID, const DirectScope(), state);

    expect(result, {foodID});
  });
}
