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
    container.listen(categoryListViewModelProvider, (previous, next) {});
    return container;
  }

  ProviderContainer buildContainerWithFailingProjection(Ledger ledger) {
    final container = ProviderContainer(
      overrides: [
        ledgerProvider.overrideWithValue(ledger),
        categoryListProjectionProvider.overrideWith(
          FailingProjectionNotifier.new,
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(categoryListViewModelProvider, (previous, next) {});
    return container;
  }

  test('requestNewCategory emits a bare CategoryFormRequested', () {
    final container = buildContainer(buildLedger([]));
    final viewModel = container.read(categoryListViewModelProvider.notifier);

    viewModel.requestNewCategory();

    final step = container.read(categoryListViewModelProvider).value?.step;
    expect(step, isA<CategoryFormRequested>());
    final requested = step as CategoryFormRequested;
    expect(requested.category, isNull);
    expect(requested.presetParentID, isNull);
  });

  test('requestEditCategory emits CategoryFormRequested for that category', () {
    final container = buildContainer(buildLedger([food]));
    final viewModel = container.read(categoryListViewModelProvider.notifier);

    viewModel.requestEditCategory(food);

    final step = container.read(categoryListViewModelProvider).value?.step;
    expect(step, isA<CategoryFormRequested>());
    final requested = step as CategoryFormRequested;
    expect(requested.category, food);
    expect(requested.presetParentID, isNull);
  });

  test(
    'requestNewSubcategory emits CategoryFormRequested preset to the parent',
    () {
      final container = buildContainer(buildLedger([food]));
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
    final viewModel = container.read(categoryListViewModelProvider.notifier);

    await viewModel.deleteCategory(food.id);

    expect(
      ledger.state.categories[food.id]!.lifecycle,
      LifecycleState.archived,
    );
    expect(container.read(categoryListViewModelProvider).value?.step, isNull);
  });

  test('clearStep resets the step to null', () {
    final container = buildContainer(buildLedger([]));
    final viewModel = container.read(categoryListViewModelProvider.notifier);

    viewModel.requestNewCategory();
    expect(
      container.read(categoryListViewModelProvider).value?.step,
      isNotNull,
    );

    viewModel.clearStep();
    expect(container.read(categoryListViewModelProvider).value?.step, isNull);
  });

  test('the first read with a ready projection is AsyncData', () {
    final container = ProviderContainer(
      overrides: [
        ledgerProvider.overrideWithValue(buildLedger([food])),
      ],
    );
    addTearDown(container.dispose);
    container.read(categoryListProjectionProvider);

    final first = container.read(categoryListViewModelProvider);

    expect(first, isA<AsyncData<CategoryListViewState>>());
  });

  test('an unmounted view model drops its pending step', () async {
    final container = ProviderContainer(
      overrides: [
        ledgerProvider.overrideWithValue(buildLedger([food])),
      ],
    );
    addTearDown(container.dispose);
    final mounted = container.listen(categoryListViewModelProvider, (_, _) {});
    container.read(categoryListViewModelProvider.notifier).requestNewCategory();

    mounted.close();
    await container.pump();

    expect(container.read(categoryListViewModelProvider).value?.step, isNull);
  });

  test('a projection failing after it had a value is an AsyncError', () {
    final container = buildContainerWithFailingProjection(buildLedger([food]));
    expect(container.read(categoryListViewModelProvider).hasValue, isTrue);

    (container.read(
      categoryListProjectionProvider.notifier,
    ) as FailingProjectionNotifier).fail();

    expect(container.read(categoryListViewModelProvider).hasError, isTrue);
  });

  test('a ledger change keeps the pending step', () {
    final ledger = buildLedger([food]);
    final container = buildContainer(ledger);
    final viewModel = container.read(categoryListViewModelProvider.notifier);
    viewModel.requestNewCategory();

    ledger.deleteCategory(food.id);

    final state = container.read(categoryListViewModelProvider).value;
    expect(state?.expense, isEmpty);
    expect(state?.step, isA<CategoryFormRequested>());
  });
}

class FailingProjectionNotifier extends CategoryListProjectionNotifier {
  void fail() {
    state = AsyncError<CategoryListProjection>(
      StateError('projection failed'),
      StackTrace.empty,
    );
  }
}
