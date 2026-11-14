import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/settings/category/category_form_view_model.dart';

class ListenerCountingLedger extends Ledger {
  int listenerCount = 0;

  @override
  void addListener(VoidCallback listener) {
    listenerCount++;
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    listenerCount--;
    super.removeListener(listener);
  }
}

void main() {
  ProviderContainer buildContainer(Ledger ledger) {
    final container = ProviderContainer(
      overrides: [ledgerProvider.overrideWithValue(ledger)],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<ProviderSubscription<AsyncValue<CategoryFormViewState>>> openAlive(
    ProviderContainer container,
    CategoryFormArgs args,
  ) async {
    final subscription = container.listen(
      categoryFormViewModelProvider(args),
      (_, _) {},
    );
    await container.read(categoryFormViewModelProvider(args).future);
    return subscription;
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
    test('locked when editing', () {
      expect(
        isKindLocked(
          isEditing: true,
          hasPresetParent: false,
          isReferenced: false,
        ),
        isTrue,
      );
    });

    test('locked when a parent is preset', () {
      expect(
        isKindLocked(
          isEditing: false,
          hasPresetParent: true,
          isReferenced: false,
        ),
        isTrue,
      );
    });

    test('locked when referenced by entries', () {
      expect(
        isKindLocked(
          isEditing: false,
          hasPresetParent: false,
          isReferenced: true,
        ),
        isTrue,
      );
    });

    test('unlocked for an add with no preset parent and no references', () {
      expect(
        isKindLocked(
          isEditing: false,
          hasPresetParent: false,
          isReferenced: false,
        ),
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

    test('excludes archived and referenceOnly roots', () {
      final binned = category(
        id: 'a0000000-0000-0000-0000-000000000004',
        name: 'Binned',
      ).settingLifecycle(LifecycleState.archived);
      final reference = category(
        id: 'a0000000-0000-0000-0000-000000000005',
        name: 'Reference',
      ).settingLifecycle(LifecycleState.referenceOnly);

      final result = eligibleParents(
        [food, binned, reference],
        CategoryKind.expense,
        excludingID: null,
      );

      expect(result, [food]);
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
      await openAlive(container, args);
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
      await openAlive(container, args);
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
      await openAlive(container, args);

      final formState = container
          .read(categoryFormViewModelProvider(args))
          .value;
      expect(formState?.kind, CategoryKind.expense);
      expect(formState?.parentID, parent.id);
      expect(formState?.title, 'Add subcategory');
      expect(formState?.kindLocked, isTrue);
    });
  });

  group('title', () {
    Future<String?> titleFor(
      ProviderContainer container,
      CategoryFormArgs args,
    ) async {
      await openAlive(container, args);
      return container.read(categoryFormViewModelProvider(args)).value?.title;
    }

    test('a new category without a parent reads Add category', () async {
      final container = buildContainer(Ledger());

      final title = await titleFor(container, const CategoryFormArgs());

      expect(title, 'Add category');
    });

    test('editing a stored root reads Edit category', () async {
      final root = category(name: 'Food');
      final ledger = Ledger(state: LedgerState(categories: {root.id: root}));
      final container = buildContainer(ledger);

      final title = await titleFor(container, CategoryFormArgs(category: root));

      expect(title, 'Edit category');
    });

    test('editing a stored child reads Edit subcategory', () async {
      final root = category(name: 'Food');
      final child = category(name: 'Snacks', parentID: root.id);
      final ledger = Ledger(
        state: LedgerState(categories: {root.id: root, child.id: child}),
      );
      final container = buildContainer(ledger);

      final title = await titleFor(
        container,
        CategoryFormArgs(category: child),
      );

      expect(title, 'Edit subcategory');
    });
  });

  group('activeSubcategories', () {
    Future<CategoryFormViewState?> stateFor(
      Ledger ledger,
      CategoryFormArgs args,
    ) async {
      final container = buildContainer(ledger);
      await openAlive(container, args);
      return container.read(categoryFormViewModelProvider(args)).value;
    }

    test('lists only active children of the edited root by name', () async {
      final root = category(name: 'Food');
      final zeta = category(name: 'Zeta', parentID: root.id);
      final alpha = category(name: 'Alpha', parentID: root.id);
      final binned = TransactionCategory(
        name: 'Binned',
        kind: CategoryKind.expense,
        colorHex: '#FF0000',
        includeInAnalysis: true,
        parentID: root.id,
        symbol: 'tag',
        lifecycle: LifecycleState.archived,
      );
      final other = category(name: 'Other');
      final stranger = category(name: 'Stranger', parentID: other.id);
      final ledger = Ledger(
        state: LedgerState(
          categories: {
            for (final c in [root, zeta, alpha, binned, other, stranger])
              c.id: c,
          },
        ),
      );

      final formState = await stateFor(
        ledger,
        CategoryFormArgs(category: root),
      );

      expect(formState?.showsSubcategories, isTrue);
      expect(formState?.activeSubcategories.map((c) => c.name), [
        'Alpha',
        'Zeta',
      ]);
    });

    test('is empty on an add form', () async {
      final root = category(name: 'Food');
      final child = category(name: 'Snacks', parentID: root.id);
      final ledger = Ledger(
        state: LedgerState(categories: {root.id: root, child.id: child}),
      );

      final formState = await stateFor(ledger, const CategoryFormArgs());

      expect(formState?.showsSubcategories, isFalse);
      expect(formState?.activeSubcategories, isEmpty);
    });

    test('is empty on a subcategory edit and add form', () async {
      final root = category(name: 'Food');
      final child = category(name: 'Snacks', parentID: root.id);
      final ledger = Ledger(
        state: LedgerState(categories: {root.id: root, child.id: child}),
      );

      final edit = await stateFor(ledger, CategoryFormArgs(category: child));
      final add = await stateFor(
        ledger,
        CategoryFormArgs(presetParentID: root.id),
      );

      expect(edit?.activeSubcategories, isEmpty);
      expect(add?.activeSubcategories, isEmpty);
    });
  });

  group('parent picker', () {
    test('requestPickParent emits PickParentRequested', () async {
      final container = buildContainer(Ledger());
      final args = const CategoryFormArgs();
      await openAlive(container, args);
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
      await openAlive(container, args);
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
        await openAlive(container, args);
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
      await openAlive(container, args);
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
      await openAlive(container, args);
      final viewModel = container.read(
        categoryFormViewModelProvider(args).notifier,
      );

      viewModel.requestPickSymbol();

      expect(
        container.read(categoryFormViewModelProvider(args)).value?.step,
        isA<PickSymbolRequested>(),
      );
    });

    test('applyPickedSymbolAndColor sets both and clears the step', () async {
      final container = buildContainer(Ledger());
      final args = const CategoryFormArgs();
      await openAlive(container, args);
      final viewModel = container.read(
        categoryFormViewModelProvider(args).notifier,
      );
      const picked = Color(0xFF34C759);

      viewModel.requestPickSymbol();
      viewModel.applyPickedSymbolAndColor('cart', picked);

      final formState = container
          .read(categoryFormViewModelProvider(args))
          .value;
      expect(formState?.symbol, 'cart');
      expect(formState?.color, picked);
      expect(formState?.step, isNull);
    });

    test('applyPickedSymbolAndColor is a no-op once disposed', () async {
      final container = buildContainer(Ledger());
      final args = const CategoryFormArgs();
      await openAlive(container, args);
      final viewModel = container.read(
        categoryFormViewModelProvider(args).notifier,
      );

      container.dispose();

      expect(
        () => viewModel.applyPickedSymbolAndColor(
          'cart',
          const Color(0xFF000000),
        ),
        returnsNormally,
      );
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
      await openAlive(container, args);
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
      await openAlive(container, args);
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
        await openAlive(container, args);
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
        await openAlive(container, args);
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
      await openAlive(container, args);

      final formState = container
          .read(categoryFormViewModelProvider(args))
          .value;
      expect(formState?.kindLocked, isTrue);
    });

    test('kind stays locked while only a binned entry references it', () async {
      final existing = category(name: 'Food');
      final account = Account(name: 'Wallet', type: AccountType.cash);
      final entry = Entry(
        name: 'Groceries',
        amount: Decimal.parse('-10'),
        date: DateTime.utc(2024, 1, 1),
        sourceID: account.id,
        categoryID: existing.id,
      ).settingLifecycle(LifecycleState.archived);
      final ledger = Ledger(
        state: LedgerState(
          categories: {existing.id: existing},
          moneySources: {account.id: MoneySource.account(account)},
          binnedEntries: {entry.id: entry},
        ),
      );
      final container = buildContainer(ledger);
      final args = CategoryFormArgs(category: existing);
      await openAlive(container, args);

      final formState = container
          .read(categoryFormViewModelProvider(args))
          .value;
      expect(formState?.kindLocked, isTrue);
    });
  });

  group('parent eligibility in the form', () {
    final root = category(
      id: 'b0000000-0000-0000-0000-000000000001',
      name: 'Food',
    );
    final binnedRoot = category(
      id: 'b0000000-0000-0000-0000-000000000002',
      name: 'Binned',
    ).settingLifecycle(LifecycleState.archived);
    final referenceRoot = category(
      id: 'b0000000-0000-0000-0000-000000000003',
      name: 'Reference',
    ).settingLifecycle(LifecycleState.referenceOnly);

    Future<CategoryFormViewState?> openForm(
      List<TransactionCategory> categories,
      CategoryFormArgs args,
    ) async {
      final ledger = Ledger(
        state: LedgerState(categories: {for (final c in categories) c.id: c}),
      );
      final container = buildContainer(ledger);
      await openAlive(container, args);
      return container.read(categoryFormViewModelProvider(args)).value;
    }

    test('offers only the active root, not binned or referenceOnly', () async {
      final formState = await openForm([
        root,
        binnedRoot,
        referenceRoot,
      ], const CategoryFormArgs());

      expect(formState?.eligibleParentsList, [root]);
    });

    test('parentLabel ignores inactive roots', () async {
      final stored = category(name: 'Orphan', parentID: binnedRoot.id);
      final formState = await openForm([
        binnedRoot,
        stored,
      ], CategoryFormArgs(category: stored));

      expect(formState?.parentLabel, isNull);
    });

    test('parentLabel resolves the preset parent', () async {
      final formState = await openForm([
        root,
      ], CategoryFormArgs(presetParentID: root.id));

      expect(formState?.parentLabel, 'Food');
    });

    test('a root whose only child is archived hides the picker', () async {
      final other = category(
        id: 'b0000000-0000-0000-0000-000000000004',
        name: 'Other',
      );
      final child = category(
        name: 'Snacks',
        parentID: root.id,
      ).settingLifecycle(LifecycleState.archived);
      final formState = await openForm([
        root,
        other,
        child,
      ], CategoryFormArgs(category: root));

      expect(formState?.storedHasChildren, isTrue);
      expect(formState?.showParentPicker, isFalse);
    });

    test('a root with no children shows the picker', () async {
      final other = category(
        id: 'b0000000-0000-0000-0000-000000000004',
        name: 'Other',
      );
      final formState = await openForm([
        root,
        other,
      ], CategoryFormArgs(category: root));

      expect(formState?.storedHasChildren, isFalse);
      expect(formState?.showParentPicker, isTrue);
    });

    test('a preset parent hides the picker', () async {
      final formState = await openForm([
        root,
      ], CategoryFormArgs(presetParentID: root.id));

      expect(formState?.showParentPicker, isFalse);
    });
  });

  group('draft parent after a ledger change', () {
    final parent = category(
      id: 'c0000000-0000-0000-0000-000000000001',
      name: 'Food',
    );
    final edited = category(
      id: 'c0000000-0000-0000-0000-000000000002',
      name: 'Home',
    );

    CategoryFormViewState? read(
      ProviderContainer container,
      CategoryFormArgs args,
    ) => container.read(categoryFormViewModelProvider(args)).value;

    test('binning the picked parent clears the draft parent', () async {
      final ledger = Ledger(
        state: LedgerState(categories: {parent.id: parent}),
      );
      final container = buildContainer(ledger);
      const args = CategoryFormArgs();
      await openAlive(container, args);
      final viewModel = container.read(
        categoryFormViewModelProvider(args).notifier,
      );
      viewModel.setName('Snacks');
      viewModel.setParentID(parent.id);

      ledger.deleteCategory(parent.id);

      final formState = read(container, args);
      expect(formState?.parentID, isNull);
      expect(formState?.parentLabel, isNull);
      expect(formState?.name, 'Snacks');
    });

    test(
      'a synced child for the edited root clears the draft parent',
      () async {
        final ledger = Ledger(
          state: LedgerState(
            categories: {parent.id: parent, edited.id: edited},
          ),
        );
        final container = buildContainer(ledger);
        final args = CategoryFormArgs(category: edited);
        await openAlive(container, args);
        container
            .read(categoryFormViewModelProvider(args).notifier)
            .setParentID(parent.id);

        ledger.addCategory(category(name: 'Rent', parentID: edited.id));

        final formState = read(container, args);
        expect(formState?.storedHasChildren, isTrue);
        expect(formState?.parentID, isNull);
      },
    );

    test('an unrelated ledger change keeps the draft parent', () async {
      final ledger = Ledger(
        state: LedgerState(categories: {parent.id: parent}),
      );
      final container = buildContainer(ledger);
      const args = CategoryFormArgs();
      await openAlive(container, args);
      container
          .read(categoryFormViewModelProvider(args).notifier)
          .setParentID(parent.id);

      ledger.addCategory(category(name: 'Transport'));

      expect(read(container, args)?.parentID, parent.id);
    });

    test('a preset parent stays when it is binned', () async {
      final ledger = Ledger(
        state: LedgerState(categories: {parent.id: parent}),
      );
      final container = buildContainer(ledger);
      final args = CategoryFormArgs(presetParentID: parent.id);
      await openAlive(container, args);

      ledger.deleteCategory(parent.id);

      expect(read(container, args)?.parentID, parent.id);
    });
  });

  group('kind lock', () {
    test('an unreferenced edit is locked', () async {
      final existing = category(name: 'Food');
      final ledger = Ledger(
        state: LedgerState(categories: {existing.id: existing}),
      );
      final container = buildContainer(ledger);
      final args = CategoryFormArgs(category: existing);
      await openAlive(container, args);

      final formState = container
          .read(categoryFormViewModelProvider(args))
          .value;
      expect(formState?.isReferenced, isFalse);
      expect(formState?.kindLocked, isTrue);
    });

    test('an add without a preset parent is unlocked', () async {
      final container = buildContainer(Ledger());
      final args = const CategoryFormArgs();
      await openAlive(container, args);

      final formState = container
          .read(categoryFormViewModelProvider(args))
          .value;
      expect(formState?.kindLocked, isFalse);
    });
  });

  group('form lifetime', () {
    const firstArgs = CategoryFormArgs();

    test('reopening New Category after it closes starts blank', () async {
      final container = buildContainer(Ledger());
      final firstOpen = await openAlive(container, firstArgs);
      container
          .read(categoryFormViewModelProvider(firstArgs).notifier)
          .setName('Stale draft');

      firstOpen.close();
      await container.pump();
      await openAlive(container, firstArgs);

      final formState = container
          .read(categoryFormViewModelProvider(firstArgs))
          .value;
      expect(formState?.name, isEmpty);
    });

    test('a parent form and a child form keep independent drafts', () async {
      final parent = category(name: 'Food');
      final ledger = Ledger(
        state: LedgerState(categories: {parent.id: parent}),
      );
      final container = buildContainer(ledger);
      final parentArgs = CategoryFormArgs(category: parent);
      final childArgs = CategoryFormArgs(presetParentID: parent.id);
      await openAlive(container, parentArgs);
      final childOpen = await openAlive(container, childArgs);
      container
          .read(categoryFormViewModelProvider(parentArgs).notifier)
          .setName('Food and drink');
      container
          .read(categoryFormViewModelProvider(childArgs).notifier)
          .setName('Snacks');

      childOpen.close();
      await container.pump();

      final parentState = container
          .read(categoryFormViewModelProvider(parentArgs))
          .value;
      expect(parentState?.name, 'Food and drink');
    });

    test('a child form closing leaves the child key blank on reopen', () async {
      final parent = category(name: 'Food');
      final ledger = Ledger(
        state: LedgerState(categories: {parent.id: parent}),
      );
      final container = buildContainer(ledger);
      final childArgs = CategoryFormArgs(presetParentID: parent.id);
      final childOpen = await openAlive(container, childArgs);
      container
          .read(categoryFormViewModelProvider(childArgs).notifier)
          .setName('Snacks');

      childOpen.close();
      await container.pump();
      await openAlive(container, childArgs);

      final childState = container
          .read(categoryFormViewModelProvider(childArgs))
          .value;
      expect(childState?.name, isEmpty);
    });
  });

  group('ledger changes', () {
    test('refresh allCategories and keep the draft, step and error', () async {
      final existing = category(name: 'Food');
      final ledger = Ledger(
        state: LedgerState(categories: {existing.id: existing}),
      );
      final container = buildContainer(ledger);
      final args = CategoryFormArgs(category: existing);
      await openAlive(container, args);
      final viewModel = container.read(
        categoryFormViewModelProvider(args).notifier,
      );
      viewModel.setName('Draft name');
      viewModel.setParentID(existing.id);
      await viewModel.save();
      viewModel.requestPickSymbol();

      ledger.addCategory(category(name: 'Transport'));

      final formState = container
          .read(categoryFormViewModelProvider(args))
          .value;
      expect(formState?.allCategories, hasLength(2));
      expect(formState?.name, 'Draft name');
      expect(formState?.error, isA<CategoryTooDeep>());
      expect(formState?.step, isA<PickSymbolRequested>());
    });

    test(
      'keep the save step when the form own save changes the ledger',
      () async {
        final ledger = Ledger();
        final container = buildContainer(ledger);
        const args = CategoryFormArgs();
        await openAlive(container, args);
        final viewModel = container.read(
          categoryFormViewModelProvider(args).notifier,
        );

        viewModel.setName('Groceries');
        await viewModel.save();

        final formState = container
            .read(categoryFormViewModelProvider(args))
            .value;
        expect(formState?.allCategories, hasLength(1));
        expect(formState?.step, isA<CategoryFormSaved>());
      },
    );

    test('stop updating once the form is disposed', () async {
      final ledger = ListenerCountingLedger();
      final container = buildContainer(ledger);
      const args = CategoryFormArgs();
      final open = await openAlive(container, args);

      open.close();
      await container.pump();

      expect(
        () => ledger.addCategory(category(name: 'Transport')),
        returnsNormally,
      );
      expect(ledger.listenerCount, 0);
    });
  });
}
