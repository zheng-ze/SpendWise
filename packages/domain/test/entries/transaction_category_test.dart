import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  const categoryID = 'abcdefab-0000-4000-8000-000000000001';

  TransactionCategory category({
    String name = 'Food',
    LifecycleState lifecycle = LifecycleState.active,
  }) => TransactionCategory(
    id: categoryID,
    name: name,
    kind: CategoryKind.expense,
    colorHex: '#123456',
    includeInAnalysis: true,
    parentID: null,
    symbol: 'tag',
    lifecycle: lifecycle,
  );

  test('setting lifecycle preserves the category and changes its state', () {
    final archived = category().settingLifecycle(LifecycleState.archived);

    expect(archived.id, categoryID);
    expect(archived.name, 'Food');
    expect(archived.kind, CategoryKind.expense);
    expect(archived.colorHex, '#123456');
    expect(archived.includeInAnalysis, isTrue);
    expect(archived.parentID, isNull);
    expect(archived.symbol, 'tag');
    expect(archived.lifecycle, LifecycleState.archived);
  });

  test(
    'category equality includes its values and supports identity lookup',
    () {
      final value = category();
      final equalValue = category();

      expect(value, equalValue);
      expect(value.hashCode, equalValue.hashCode);
      expect(value, isNot(category(name: 'Dining')));
      expect(value, isNot(category(lifecycle: LifecycleState.archived)));
      expect({value: 'food'}[equalValue], 'food');
    },
  );
}
