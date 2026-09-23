import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/settings/category/category_form_view_model.dart';

void main() {
  ProviderContainer buildContainer(Ledger ledger) {
    final container = ProviderContainer(
      overrides: [ledgerProvider.overrideWithValue(ledger)],
    );
    addTearDown(container.dispose);
    return container;
  }

  TransactionCategory category({
    String? id,
    required String name,
    CategoryKind kind = CategoryKind.expense,
    String? parentID,
  }) => TransactionCategory(
    id: id,
    name: name,
    kind: kind,
    colorHex: '#FF0000',
    includeInAnalysis: true,
    parentID: parentID,
    symbol: 'tag',
  );

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
    final food = category(
      id: 'a0000000-0000-0000-0000-000000000001',
      name: 'Food',
    );
    final snacks = category(
      id: 'a0000000-0000-0000-0000-000000000002',
      name: 'Snacks',
      parentID: food.id,
    );
    final salary = category(
      id: 'a0000000-0000-0000-0000-000000000003',
      name: 'Salary',
      kind: CategoryKind.income,
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

  group('creating a category', () {
    test('cannot save with a blank name', () async {
      final container = buildContainer(Ledger());
      final args = const CategoryFormArgs();
      await container.read(categoryFormViewModelProvider(args).future);
      final viewModel = container.read(
        categoryFormViewModelProvider(args).notifier,
      );

      viewModel.setName('   ');

      expect(
        container.read(categoryFormViewModelProvider(args)).value?.canSave,
        isFalse,
      );
    });

    test('saving a new category adds it to the ledger', () async {
      final ledger = Ledger();
      final container = buildContainer(ledger);
      final args = const CategoryFormArgs();
      await container.read(categoryFormViewModelProvider(args).future);
      final viewModel = container.read(
        categoryFormViewModelProvider(args).notifier,
      );

      viewModel.setName('Groceries');
      await viewModel.save();

      expect(ledger.state.categories.values, hasLength(1));
      expect(ledger.state.categories.values.single.name, 'Groceries');
      expect(
        container.read(categoryFormViewModelProvider(args)).value?.step,
        isA<CategoryFormSaved>(),
      );
    });

    test('a preset parent prefills the kind and parent id', () async {
      final parent = category(name: 'Food');
      final ledger = Ledger(
        state: LedgerState(categories: {parent.id: parent}),
      );
      final container = buildContainer(ledger);
      final args = CategoryFormArgs(presetParentID: parent.id);
      await container.read(categoryFormViewModelProvider(args).future);

      final formState = container
          .read(categoryFormViewModelProvider(args))
          .value;
      expect(formState?.kind, CategoryKind.expense);
      expect(formState?.parentID, parent.id);
      expect(formState?.title, 'New Subcategory');
      expect(formState?.kindLocked, isTrue);
    });
  });

  group('parent picker', () {
    test('requestPickParent emits PickParentRequested', () async {
      final container = buildContainer(Ledger());
      final args = const CategoryFormArgs();
      await container.read(categoryFormViewModelProvider(args).future);
      final viewModel = container.read(
        categoryFormViewModelProvider(args).notifier,
      );

      viewModel.requestPickParent();

      expect(
        container.read(categoryFormViewModelProvider(args)).value?.step,
        isA<PickParentRequested>(),
      );
    });

    test('applyPickedParent sets the parent and clears the step', () async {
      final parent = category(name: 'Food');
      final ledger = Ledger(
        state: LedgerState(categories: {parent.id: parent}),
      );
      final container = buildContainer(ledger);
      final args = const CategoryFormArgs();
      await container.read(categoryFormViewModelProvider(args).future);
      final viewModel = container.read(
        categoryFormViewModelProvider(args).notifier,
      );

      viewModel.requestPickParent();
      viewModel.applyPickedParent(parent.id);

      final formState = container
          .read(categoryFormViewModelProvider(args))
          .value;
      expect(formState?.parentID, parent.id);
      expect(formState?.step, isNull);
    });

    test(
      'applyPickedParent is a no-op once the provider is disposed',
      () async {
        final container = buildContainer(Ledger());
        final args = const CategoryFormArgs();
        await container.read(categoryFormViewModelProvider(args).future);
        final viewModel = container.read(
          categoryFormViewModelProvider(args).notifier,
        );

        container.dispose();

        expect(() => viewModel.applyPickedParent('some-id'), returnsNormally);
      },
    );

    test('changing kind clears a parent that no longer matches', () async {
      final expenseParent = category(name: 'Food');
      final ledger = Ledger(
        state: LedgerState(categories: {expenseParent.id: expenseParent}),
      );
      final container = buildContainer(ledger);
      final args = const CategoryFormArgs();
      await container.read(categoryFormViewModelProvider(args).future);
      final viewModel = container.read(
        categoryFormViewModelProvider(args).notifier,
      );

      viewModel.applyPickedParent(expenseParent.id);
      viewModel.setKind(CategoryKind.income);

      expect(
        container.read(categoryFormViewModelProvider(args)).value?.parentID,
        isNull,
      );
    });
  });

  group('symbol picker', () {
    test('requestPickSymbol emits PickSymbolRequested', () async {
      final container = buildContainer(Ledger());
      final args = const CategoryFormArgs();
      await container.read(categoryFormViewModelProvider(args).future);
      final viewModel = container.read(
        categoryFormViewModelProvider(args).notifier,
      );

      viewModel.requestPickSymbol();

      expect(
        container.read(categoryFormViewModelProvider(args)).value?.step,
        isA<PickSymbolRequested>(),
      );
    });

    test('applyPickedSymbol sets the symbol and clears the step', () async {
      final container = buildContainer(Ledger());
      final args = const CategoryFormArgs();
      await container.read(categoryFormViewModelProvider(args).future);
      final viewModel = container.read(
        categoryFormViewModelProvider(args).notifier,
      );

      viewModel.requestPickSymbol();
      viewModel.applyPickedSymbol('cart');

      final formState = container
          .read(categoryFormViewModelProvider(args))
          .value;
      expect(formState?.symbol, 'cart');
      expect(formState?.step, isNull);
    });
  });

  group('editing and deleting a category', () {
    test('save failure surfaces a LedgerError', () async {
      final existing = category(name: 'Food');
      final ledger = Ledger(
        state: LedgerState(categories: {existing.id: existing}),
      );
      final container = buildContainer(ledger);
      final args = CategoryFormArgs(category: existing);
      await container.read(categoryFormViewModelProvider(args).future);
      final viewModel = container.read(
        categoryFormViewModelProvider(args).notifier,
      );

      viewModel.setParentID(existing.id);
      await viewModel.save();

      final formState = container
          .read(categoryFormViewModelProvider(args))
          .value;
      expect(formState?.error, isA<CategoryTooDeep>());
    });

    test('requestDelete emits DeleteConfirmationRequested', () async {
      final existing = category(name: 'Food');
      final ledger = Ledger(
        state: LedgerState(categories: {existing.id: existing}),
      );
      final container = buildContainer(ledger);
      final args = CategoryFormArgs(category: existing);
      await container.read(categoryFormViewModelProvider(args).future);
      final viewModel = container.read(
        categoryFormViewModelProvider(args).notifier,
      );

      viewModel.requestDelete();

      expect(
        container.read(categoryFormViewModelProvider(args)).value?.step,
        isA<DeleteConfirmationRequested>(),
      );
    });

    test(
      'applyDeleteConfirmed(true) deletes and emits CategoryFormSaved',
      () async {
        final existing = category(name: 'Food');
        final ledger = Ledger(
          state: LedgerState(categories: {existing.id: existing}),
        );
        final container = buildContainer(ledger);
        final args = CategoryFormArgs(category: existing);
        await container.read(categoryFormViewModelProvider(args).future);
        final viewModel = container.read(
          categoryFormViewModelProvider(args).notifier,
        );

        viewModel.requestDelete();
        await viewModel.applyDeleteConfirmed(true);

        expect(
          ledger.state.categories[existing.id]?.lifecycle,
          LifecycleState.archived,
        );
        expect(
          container.read(categoryFormViewModelProvider(args)).value?.step,
          isA<CategoryFormSaved>(),
        );
      },
    );

    test(
      'applyDeleteConfirmed(false) keeps the category and clears the step',
      () async {
        final existing = category(name: 'Food');
        final ledger = Ledger(
          state: LedgerState(categories: {existing.id: existing}),
        );
        final container = buildContainer(ledger);
        final args = CategoryFormArgs(category: existing);
        await container.read(categoryFormViewModelProvider(args).future);
        final viewModel = container.read(
          categoryFormViewModelProvider(args).notifier,
        );

        viewModel.requestDelete();
        await viewModel.applyDeleteConfirmed(false);

        expect(ledger.state.categories, hasLength(1));
        expect(
          container.read(categoryFormViewModelProvider(args)).value?.step,
          isNull,
        );
      },
    );

    test('kind is locked while transactions reference the category', () async {
      final existing = category(name: 'Food');
      final account = Account(name: 'Wallet', type: AccountType.cash);
      final entry = Entry(
        name: 'Groceries',
        amount: Decimal.parse('-10'),
        date: DateTime.utc(2024, 1, 1),
        sourceID: account.id,
        categoryID: existing.id,
      );
      final ledger = Ledger(
        state: LedgerState(
          categories: {existing.id: existing},
          moneySources: {account.id: MoneySource.account(account)},
          entries: {entry.id: entry},
        ),
      );
      final container = buildContainer(ledger);
      final args = CategoryFormArgs(category: existing);
      await container.read(categoryFormViewModelProvider(args).future);

      final formState = container
          .read(categoryFormViewModelProvider(args))
          .value;
      expect(formState?.kindLocked, isTrue);
    });
  });
}
