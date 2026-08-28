import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/common/category_icon.dart';
import 'package:spendwise/ui/common/swipe_to_delete_row.dart';
import 'package:spendwise/ui/format/color_hex.dart';
import 'package:spendwise/ui/settings/category_form.dart';
import 'package:spendwise/ui/settings/category_list_view_model.dart';

class CategoryListScreen extends ConsumerStatefulWidget {
  const CategoryListScreen({super.key});

  @override
  ConsumerState<CategoryListScreen> createState() => _CategoryListScreenState();
}

class _CategoryListScreenState extends ConsumerState<CategoryListScreen> {
  ProviderSubscription<AsyncValue<CategoryListViewState>>? _stepSubscription;

  @override
  void initState() {
    super.initState();
    _stepSubscription = ref.listenManual(
      categoryListViewModelProvider,
      (previous, next) => _handleStep(next.value?.step),
    );
  }

  @override
  void dispose() {
    _stepSubscription?.close();
    super.dispose();
  }

  CategoryListViewModel get _viewModel =>
      ref.read(categoryListViewModelProvider.notifier);

  void _handleStep(CategoryListStep? step) {
    if (step == null) return;
    switch (step) {
      case CategoryFormRequested(:final category, :final presetParentID):
        _openForm(category: category, presetParentID: presetParentID);
    }
  }

  Future<void> _openForm({
    TransactionCategory? category,
    String? presetParentID,
  }) async {
    _viewModel.clearStep();
    await showCategoryFormSheet(
      context: context,
      category: category,
      presetParentID: presetParentID,
    );
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(categoryListViewModelProvider);

    return asyncState.when(
      data: (viewState) =>
          _CategoryListScreenBody(viewState: viewState, viewModel: _viewModel),
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) =>
          Scaffold(body: Center(child: Text('$error'))),
    );
  }
}

class _CategoryListScreenBody extends StatelessWidget {
  const _CategoryListScreenBody({
    required this.viewState,
    required this.viewModel,
  });

  final CategoryListViewState viewState;
  final CategoryListViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: viewModel.requestNewCategory,
          ),
        ],
      ),
      body: ListView(
        children: [
          _CategorySection(
            title: 'Income',
            categories: viewState.income,
            onTap: viewModel.requestEditCategory,
            onDeleted: (category) => viewModel.deleteCategory(category.id),
            onAddSubcategory: viewModel.requestNewSubcategory,
          ),
          _CategorySection(
            title: 'Expense',
            categories: viewState.expense,
            onTap: viewModel.requestEditCategory,
            onDeleted: (category) => viewModel.deleteCategory(category.id),
            onAddSubcategory: viewModel.requestNewSubcategory,
          ),
        ],
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.title,
    required this.categories,
    required this.onTap,
    required this.onDeleted,
    required this.onAddSubcategory,
  });

  final String title;
  final List<TransactionCategory> categories;
  final void Function(TransactionCategory category) onTap;
  final void Function(TransactionCategory category) onDeleted;
  final void Function(TransactionCategory parent) onAddSubcategory;

  Widget _title(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        'No categories yet',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Iterable<Widget> _categoryList() {
    return categories.map(
      (category) => SwipeToDeleteRow(
        itemKey: ValueKey('category-${category.id}'),
        itemName: category.name,
        onDeleted: () => onDeleted(category),
        child: _CategoryRow(
          category: category,
          onTap: () => onTap(category),
          onAddSubcategory: category.parentID == null
              ? () => onAddSubcategory(category)
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title(context),
        if (categories.isEmpty) _emptyState(context) else ..._categoryList(),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.onTap,
    required this.onAddSubcategory,
  });

  final TransactionCategory category;
  final VoidCallback onTap;
  final VoidCallback? onAddSubcategory;

  @override
  Widget build(BuildContext context) {
    final indent = category.parentID != null ? 24.0 : 0.0;
    final color = parseColorHex(category.colorHex);

    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.only(left: 16 + indent, right: 8),
      leading: CategoryIcon(
        symbolName: category.symbol,
        color: color,
        size: 30,
      ),
      title: Text(category.name),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!category.includeInAnalysis)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.bar_chart),
            ),
          if (onAddSubcategory != null)
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: onAddSubcategory,
            ),
        ],
      ),
    );
  }
}
