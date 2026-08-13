import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  test('Decimal is nameable through the barrel alone', () {
    final Decimal amount = Decimal.fromInt(-25);

    expect(amount, Decimal.parse('-25'));
    expect(
      Entry(amount: amount, name: 'rent', sourceID: _accountID).amount,
      isA<Decimal>(),
    );
  });

  test('the accounting types are nameable through the barrel alone', () {
    final NetWorth worth = NetWorth(Decimal.zero, Decimal.zero);
    final DateRange window = DateRange(
      DateTime.utc(2026, 4),
      DateTime.utc(2026, 5),
    );
    final AnalysisItem item = AnalysisItem(
      bucketID: null,
      amount: Decimal.fromInt(1),
      date: DateTime.utc(2026, 4, 15),
      kind: CategoryKind.expense,
    );
    const CategoryResolution resolution = Uncategorized();

    expect(worth.asset, Decimal.zero);
    expect(window.contains(item.date), isTrue);
    expect(resolution, isA<CategoryResolution>());
    expect(Accounting.netWorth(LedgerState()), worth);
  });

  test('replay is nameable through the barrel alone', () {
    final LedgerState state = LedgerState.replaying([
      UpsertEntry(
        Entry(amount: Decimal.one, name: 'rent', sourceID: _accountID),
      ),
    ]);
    state.apply([UpsertCategory(_category)]);

    expect(state.entries.values.single.name, 'rent');
    expect(state.categories[_category.id], _category);
  });
}

final _category = TransactionCategory(
  id: '00000000-0000-4000-8000-000000000002',
  name: 'food',
  kind: CategoryKind.expense,
  colorHex: '#888888',
  includeInAnalysis: true,
  parentID: null,
  symbol: 'tag',
);

const _accountID = '00000000-0000-4000-8000-000000000001';
