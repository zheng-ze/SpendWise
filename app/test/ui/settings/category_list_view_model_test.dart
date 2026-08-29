import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/settings/category_list_view_model.dart';

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

  test('build groups categories into income and expense lists', () async {
    final container = buildContainer(buildLedger([food, snacks, salary]));
    await container.read(categoryListViewModelProvider.future);

    final viewState = container.read(categoryListViewModelProvider).value!;
    expect(viewState.income.map((c) => c.id), [salary.id]);
    expect(viewState.expense.map((c) => c.id), [food.id, snacks.id]);
  });

  test('requestNewCategory emits a bare CategoryFormRequested', () async {
    final container = buildContainer(buildLedger([]));
    await container.read(categoryListViewModelProvider.future);
    final viewModel = container.read(categoryListViewModelProvider.notifier);

    viewModel.requestNewCategory();

    final step = container.read(categoryListViewModelProvider).value?.step;
    expect(step, isA<CategoryFormRequested>());
    final requested = step as CategoryFormRequested;
    expect(requested.category, isNull);
    expect(requested.presetParentID, isNull);
  });

  test(
    'requestEditCategory emits CategoryFormRequested for that category',
    () async {
      final container = buildContainer(buildLedger([food]));
      await container.read(categoryListViewModelProvider.future);
      final viewModel = container.read(categoryListViewModelProvider.notifier);

      viewModel.requestEditCategory(food);

      final step = container.read(categoryListViewModelProvider).value?.step;
      expect(step, isA<CategoryFormRequested>());
      final requested = step as CategoryFormRequested;
      expect(requested.category, food);
      expect(requested.presetParentID, isNull);
    },
  );

  test(
    'requestNewSubcategory emits CategoryFormRequested preset to the parent',
    () async {
      final container = buildContainer(buildLedger([food]));
      await container.read(categoryListViewModelProvider.future);
      final viewModel = container.read(categoryListViewModelProvider.notifier);

      viewModel.requestNewSubcategory(food);

      final step = container.read(categoryListViewModelProvider).value?.step;
      expect(step, isA<CategoryFormRequested>());
      final requested = step as CategoryFormRequested;
      expect(requested.category, isNull);
      expect(requested.presetParentID, food.id);
    },
  );

  test('deleteCategory archives the category and needs no step', () async {
    final ledger = buildLedger([food]);
    final container = buildContainer(ledger);
    await container.read(categoryListViewModelProvider.future);
    final viewModel = container.read(categoryListViewModelProvider.notifier);

    await viewModel.deleteCategory(food.id);

    expect(
      ledger.state.categories[food.id]!.lifecycle,
      LifecycleState.archived,
    );
    expect(container.read(categoryListViewModelProvider).value?.step, isNull);
  });

  test('clearStep resets the step to null', () async {
    final container = buildContainer(buildLedger([]));
    await container.read(categoryListViewModelProvider.future);
    final viewModel = container.read(categoryListViewModelProvider.notifier);

    viewModel.requestNewCategory();
    expect(
      container.read(categoryListViewModelProvider).value?.step,
      isNotNull,
    );

    viewModel.clearStep();
    expect(container.read(categoryListViewModelProvider).value?.step, isNull);
  });
}
