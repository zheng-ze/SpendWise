import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/settings/category/category_list_view_model.dart';

void main() {
  final food = TransactionCategory(
    id: 'a0000000-0000-0000-0000-000000000001',
    name: 'Food',
    kind: CategoryKind.expense,
    colorHex: '#FF0000',
    includeInAnalysis: true,
    parentID: null,
    symbol: 'restaurant',
  );
  final snacks = TransactionCategory(
    id: 'a0000000-0000-0000-0000-000000000002',
    name: 'Snacks',
    kind: CategoryKind.expense,
    colorHex: '#FF0000',
    includeInAnalysis: true,
    parentID: food.id,
    symbol: 'cake',
  );
  final salary = TransactionCategory(
    id: 'a0000000-0000-0000-0000-000000000003',
    name: 'Salary',
    kind: CategoryKind.income,
    colorHex: '#0000FF',
    includeInAnalysis: true,
    parentID: null,
    symbol: 'payments',
  );

  Ledger buildLedger(List<TransactionCategory> categories) {
    return Ledger(
      state: LedgerState(categories: {for (final c in categories) c.id: c}),
    );
  }

  ProviderContainer buildContainer(Ledger ledger) {
    final container = ProviderContainer(
      overrides: [ledgerProvider.overrideWithValue(ledger)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('groups categories into income and expense lists', () {
    final container = buildContainer(buildLedger([food, snacks, salary]));

    final projection = container
        .read(categoryListProjectionProvider)
        .requireValue;

    expect(projection.income.map((c) => c.id), [salary.id]);
    expect(projection.expense.map((c) => c.id), [food.id, snacks.id]);
  });

  test('a ledger change refreshes the income and expense lists', () {
    final ledger = buildLedger([food, snacks, salary]);
    final container = buildContainer(ledger);
    container.listen(categoryListProjectionProvider, (previous, next) {});

    ledger.deleteCategory(snacks.id);

    final projection = container
        .read(categoryListProjectionProvider)
        .requireValue;
    expect(projection.expense.map((c) => c.id), [food.id]);
  });
}
