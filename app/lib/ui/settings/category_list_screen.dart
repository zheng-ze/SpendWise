import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/common/category_icon.dart';
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

class _CategoryListScreenBody extends StatefulWidget {
  const _CategoryListScreenBody({required this.ledger});

  final Ledger ledger;

  @override
  State<_CategoryListScreenBody> createState() =>
      _CategoryListScreenBodyState();
}

class _CategoryListScreenBodyState extends State<_CategoryListScreenBody> {
  bool _editing = false;

  void _toggleEditing() => setState(() => _editing = !_editing);

  Future<void> _confirmAndDelete(TransactionCategory category) async {
    final referenceCount = widget.ledger.state.entryCountReferencing(
      category.id,
    );
    final entryWord = referenceCount == 1 ? 'transaction' : 'transactions';
    final message = referenceCount > 0
        ? '$referenceCount $entryWord will become Uncategorized.'
        : 'This category will be removed.';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${category.name}?'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) widget.ledger.deleteCategory(category.id);
  }

  void _openForm({TransactionCategory? category, String? presetParentID}) {
    showCategoryFormSheet(
      context: context,
      ledger: widget.ledger,
      category: category,
      presetParentID: presetParentID,
    );
  }

  @override
  Widget build(BuildContext context) {
    final income = widget.ledger.categories(CategoryKind.income);
    final expense = widget.ledger.categories(CategoryKind.expense);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        actions: [
          TextButton(
            onPressed: _toggleEditing,
            child: Text(_editing ? 'Done' : 'Edit'),
          ),
          IconButton(icon: const Icon(Icons.add), onPressed: () => _openForm()),
        ],
      ),
      body: ListView(
        children: [
          _CategorySection(
            title: 'Income',
            categories: income,
            editing: _editing,
            onTap: (category) => _openForm(category: category),
            onDelete: _confirmAndDelete,
            onAddSubcategory: (parent) => _openForm(presetParentID: parent.id),
          ),
          _CategorySection(
            title: 'Expense',
            categories: expense,
            editing: _editing,
            onTap: (category) => _openForm(category: category),
            onDelete: _confirmAndDelete,
            onAddSubcategory: (parent) => _openForm(presetParentID: parent.id),
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
    required this.editing,
    required this.onTap,
    required this.onDelete,
    required this.onAddSubcategory,
  });

  final String title;
  final List<TransactionCategory> categories;
  final bool editing;
  final void Function(TransactionCategory category) onTap;
  final Future<void> Function(TransactionCategory category) onDelete;
  final void Function(TransactionCategory parent) onAddSubcategory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        if (categories.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'No categories yet',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          for (final category in categories)
            Semantics(
              customSemanticsActions: {
                CustomSemanticsAction(label: 'Delete ${category.name}'): () =>
                    onDelete(category),
              },
              child: Dismissible(
                key: ValueKey('category-${category.id}'),
                direction: DismissDirection.endToStart,
                background: const _DeleteBackground(),
                confirmDismiss: (_) async {
                  await onDelete(category);
                  return false;
                },
                child: _CategoryRow(
                  category: category,
                  editing: editing,
                  onTap: () => onTap(category),
                  onDelete: () => onDelete(category),
                  onAddSubcategory: category.parentID == null
                      ? () => onAddSubcategory(category)
                      : null,
                ),
              ),
            ),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.editing,
    required this.onTap,
    required this.onDelete,
    required this.onAddSubcategory,
  });

  final TransactionCategory category;
  final bool editing;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback? onAddSubcategory;

  @override
  Widget build(BuildContext context) {
    final indent = category.parentID != null ? 24.0 : 0.0;
    final color = parseColorHex(category.colorHex);

    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.only(left: 16 + indent, right: 8),
      leading: editing
          ? IconButton(
              icon: const Icon(Icons.remove_circle, color: Colors.red),
              onPressed: onDelete,
            )
          : CategoryIcon(symbolName: category.symbol, color: color, size: 30),
      title: Text(category.name),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!category.includeInAnalysis)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.bar_chart),
            ),
          if (!editing && onAddSubcategory != null)
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: onAddSubcategory,
            ),
        ],
      ),
    );
  }
}

class _DeleteBackground extends StatelessWidget {
  const _DeleteBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.error,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: const Icon(Icons.delete_outline, color: Colors.white),
    );
  }
}
