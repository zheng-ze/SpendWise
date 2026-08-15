import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/settings/category_form_logic.dart';

void main() {
  group('isKindLocked', () {
    test('locked when a parent is preset', () {
      expect(isKindLocked(hasPresetParent: true, isReferenced: false), isTrue);
    });

    test('locked when referenced by entries', () {
      expect(isKindLocked(hasPresetParent: false, isReferenced: true), isTrue);
    });

    test('unlocked with no preset parent and no references', () {
      expect(
        isKindLocked(hasPresetParent: false, isReferenced: false),
        isFalse,
      );
    });
  });

  group('canSaveCategoryForm', () {
    test('blank name cannot save', () {
      expect(canSaveCategoryForm(''), isFalse);
    });

    test('whitespace-only name cannot save', () {
      expect(canSaveCategoryForm('   '), isFalse);
    });

    test('trimmed non-empty name can save', () {
      expect(canSaveCategoryForm('  Groceries  '), isTrue);
    });
  });

  group('eligibleParents', () {
    final food = TransactionCategory(
      id: 'a0000000-0000-0000-0000-000000000001',
      name: 'Food',
      kind: CategoryKind.expense,
      colorHex: '#FF0000',
      includeInAnalysis: true,
      parentID: null,
      symbol: 'tag',
    );
    final snacks = TransactionCategory(
      id: 'a0000000-0000-0000-0000-000000000002',
      name: 'Snacks',
      kind: CategoryKind.expense,
      colorHex: '#FF0000',
      includeInAnalysis: true,
      parentID: food.id,
      symbol: 'tag',
    );
    final salary = TransactionCategory(
      id: 'a0000000-0000-0000-0000-000000000003',
      name: 'Salary',
      kind: CategoryKind.income,
      colorHex: '#00FF00',
      includeInAnalysis: true,
      parentID: null,
      symbol: 'tag',
    );

    final categories = [food, snacks, salary];

    test('offers only root categories of the matching kind', () {
      final result = eligibleParents(
        categories,
        CategoryKind.expense,
        excludingID: null,
      );
      expect(result, [food]);
    });

    test('excludes the category itself', () {
      final result = eligibleParents(
        categories,
        CategoryKind.expense,
        excludingID: food.id,
      );
      expect(result, isEmpty);
    });

    test('a subcategory never appears, even unexcluded', () {
      final result = eligibleParents(
        categories,
        CategoryKind.expense,
        excludingID: null,
      );
      expect(result.map((c) => c.id), isNot(contains(snacks.id)));
    });
  });
}
