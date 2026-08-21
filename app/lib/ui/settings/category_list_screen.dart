import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/common/category_icon.dart';
import 'package:spendwise/ui/common/swipe_to_delete_row.dart';
import 'package:spendwise/ui/format/color_hex.dart';
import 'package:spendwise/ui/settings/category_form.dart';

class CategoryListScreen extends ConsumerWidget {
  const CategoryListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledger = ref.watch(ledgerProvider);
    if (ledger == null) return const SizedBox.shrink();

    return ListenableBuilder(
      listenable: ledger,
      builder: (context, _) => _CategoryListScreenBody(ledger: ledger),
    );
  }
}

class _CategoryListScreenBody extends StatelessWidget {
  const _CategoryListScreenBody({required this.ledger});

  final Ledger ledger;

  void _openForm(
    BuildContext context, {
    TransactionCategory? category,
    String? presetParentID,
  }) {
    showCategoryFormSheet(
      context: context,
      ledger: ledger,
      category: category,
      presetParentID: presetParentID,
    );
  }

  @override
  Widget build(BuildContext context) {
    final income = ledger.categories(CategoryKind.income);
    final expense = ledger.categories(CategoryKind.expense);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _openForm(context),
          ),
        ],
      ),
      body: ListView(
        children: [
          _CategorySection(
            title: 'Income',
            categories: income,
            onTap: (category) => _openForm(context, category: category),
            onDeleted: (category) => ledger.deleteCategory(category.id),
            onAddSubcategory: (parent) =>
                _openForm(context, presetParentID: parent.id),
          ),
          _CategorySection(
            title: 'Expense',
            categories: expense,
            onTap: (category) => _openForm(context, category: category),
            onDeleted: (category) => ledger.deleteCategory(category.id),
            onAddSubcategory: (parent) =>
                _openForm(context, presetParentID: parent.id),
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
