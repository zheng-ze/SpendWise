import 'dart:async';

import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/common/feedback/async_value_view.dart';
import 'package:spendwise/ui/common/lists/category_icon.dart';
import 'package:spendwise/ui/common/lists/medallion_row.dart';
import 'package:spendwise/ui/common/lists/swipe_row.dart';
import 'package:spendwise/ui/common/navigation/compact_labelled_fab.dart';
import 'package:spendwise/ui/common/navigation/labelled_back_button.dart';
import 'package:spendwise/ui/common/sheets/app_sheet_route.dart';
import 'package:spendwise/ui/common/sheets/sheet_session.dart';
import 'package:spendwise/ui/common/sheets/tray.dart';
import 'package:spendwise/ui/settings/category/category_form.dart';
import 'package:spendwise/ui/settings/category/category_list_view_model.dart';
import 'package:spendwise/ui/theme/category_palette.dart';
import 'package:spendwise/ui/theme/spendwise_colors.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

// MARK: - CategoryListScreen
class CategoryListScreen extends ConsumerStatefulWidget {
  const CategoryListScreen({super.key});

  @override
  ConsumerState<CategoryListScreen> createState() => _CategoryListScreenState();
}

// MARK: - CategoryListScreenState
class _CategoryListScreenState extends ConsumerState<CategoryListScreen> {
  ProviderSubscription<AsyncValue<CategoryListViewState>>? _stepSubscription;
  SheetSession? _formSheet;

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
    _formSheet?.retire();
    _formSheet = null;
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

  void _openForm({TransactionCategory? category, String? presetParentID}) {
    _viewModel.clearStep();
    if (_formSheet != null) return;
    final sheet = SheetSession();
    _formSheet = sheet;
    void trackRoute(AppSheetRoute<void> route) {
      sheet.route = route;
      unawaited(_releaseFormSheetWhenClosed(route, sheet));
    }

    unawaited(
      showCategoryFormSheet(
        context: context,
        category: category,
        presetParentID: presetParentID,
        onRouteCreated: trackRoute,
      ),
    );
  }

  Future<void> _releaseFormSheetWhenClosed(
    AppSheetRoute<void> route,
    SheetSession sheet,
  ) async {
    await route.completed;
    if (identical(_formSheet, sheet)) _formSheet = null;
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(categoryListViewModelProvider);

    return AsyncValueView(
      value: asyncState,
      onRetry: () => ref.invalidate(categoryListViewModelProvider),
      fullPage: true,
      data: (viewState) =>
          _CategoryListScreenBody(viewState: viewState, viewModel: _viewModel),
    );
  }
}

// MARK: - Subcategory meta
String? categorySubcategoriesMeta(int count) {
  if (count == 0) return null;
  if (count == 1) return '1 subcategory';
  return '$count subcategories';
}

// MARK: - CategoryListScreenBody
class _CategoryListScreenBody extends StatelessWidget {
  const _CategoryListScreenBody({
    required this.viewState,
    required this.viewModel,
  });

  final CategoryListViewState viewState;
  final CategoryListViewModel viewModel;

  static const _screenTitle = 'Categories';
  static const _backLabel = 'Settings';
  static const _contentPadding = EdgeInsets.all(12);
  static const _sectionGap = 10.0;
  static const _addLabel = 'Add category';
  static const _fabPadding = EdgeInsets.only(right: 12, bottom: 12);

  @override
  Widget build(BuildContext context) {
    final backButton = LabelledBackButton(
      onPressed: Navigator.of(context).maybePop,
      label: _backLabel,
    );
    final expense = _CategorySection(
      title: 'Expense',
      categories: viewState.expense,
      onTap: viewModel.requestEditCategory,
      onDeleted: (category) => viewModel.deleteCategory(category.id),
      onAddSubcategory: viewModel.requestNewSubcategory,
    );
    final income = _CategorySection(
      title: 'Income',
      categories: viewState.income,
      onTap: viewModel.requestEditCategory,
      onDeleted: (category) => viewModel.deleteCategory(category.id),
      onAddSubcategory: viewModel.requestNewSubcategory,
    );
    final sections = ListView(
      padding: _contentPadding,
      children: [
        expense,
        const SizedBox(height: _sectionGap),
        income,
        const FabReserveSpace(),
      ],
    );
    final addButton = CompactLabelledFab(
      label: _addLabel,
      icon: Icons.add,
      onPressed: viewModel.requestNewCategory,
    );
    final floatingAction = Align(
      alignment: Alignment.bottomRight,
      child: Padding(padding: _fabPadding, child: addButton),
    );

    return Scaffold(
      appBar: AppBar(leading: backButton, title: const Text(_screenTitle)),
      body: Stack(children: [sections, floatingAction]),
    );
  }
}

// MARK: - CategorySection
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

  static const _emptyText = 'No categories yet';
  static const _labelWeight = FontWeight.w600;
  static const _labelGap = 10.0;
  static const _emptyPadding = EdgeInsets.symmetric(vertical: 8);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final label = Text(
      title.toUpperCase(),
      style: context.text.small.copyWith(
        color: colors.subtext,
        fontWeight: _labelWeight,
      ),
    );
    final rows = categories.isEmpty
        ? [
            Padding(
              padding: _emptyPadding,
              child: Text(_emptyText, style: TextStyle(color: colors.subtext)),
            ),
          ]
        : _rows(colors);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        label,
        const SizedBox(height: _labelGap),
        Tray(child: Column(children: rows)),
      ],
    );
  }

  List<Widget> _rows(SpendWiseColors colors) {
    final childCounts = <String, int>{};
    for (final category in categories) {
      final parentID = category.parentID;
      if (parentID != null) {
        childCounts[parentID] = (childCounts[parentID] ?? 0) + 1;
      }
    }
    final rows = <Widget>[];
    for (final (index, category) in categories.indexed) {
      if (index > 0) rows.add(_RowDivider(color: colors.edge));
      rows.add(
        SwipeRow(
          itemKey: ValueKey('category-${category.id}'),
          itemName: category.name,
          onDeleted: () => onDeleted(category),
          child: _CategoryRow(
            category: category,
            subcategoryCount: childCounts[category.id] ?? 0,
            onTap: () => onTap(category),
            onAddSubcategory: category.parentID == null
                ? () => onAddSubcategory(category)
                : null,
          ),
        ),
      );
    }
    return rows;
  }
}

// MARK: - RowDivider
class _RowDivider extends StatelessWidget {
  const _RowDivider({required this.color});

  final Color color;

  static const _height = 1.0;

  @override
  Widget build(BuildContext context) =>
      Container(height: _height, color: color);
}

// MARK: - CategoryRow
class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.subcategoryCount,
    required this.onTap,
    required this.onAddSubcategory,
  });

  final TransactionCategory category;
  final int subcategoryCount;
  final VoidCallback onTap;
  final VoidCallback? onAddSubcategory;

  static const _rootIndent = 0.0;
  static const _childIndent = 36.0;
  static const _rowVerticalPadding = 7.0;
  static const _medallionSize = 30.0;
  static const _chevronSize = 13.0;
  static const _badgeSize = 16.0;
  static const _trailingGap = 4.0;
  static const _addTooltip = 'Add subcategory';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final indent = category.parentID == null ? _rootIndent : _childIndent;
    final medallion = CategoryIcon(
      symbolName: category.symbol,
      color: CategoryPalette.savedColor(category.colorHex, colors),
      size: _medallionSize,
    );
    final addSubcategory = onAddSubcategory;
    final trailing = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!category.includeInAnalysis)
          Icon(Icons.bar_chart, size: _badgeSize, color: colors.subtext),
        if (addSubcategory != null)
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: _addTooltip,
            onPressed: addSubcategory,
          ),
        const SizedBox(width: _trailingGap),
        Icon(Icons.chevron_right, size: _chevronSize, color: colors.subtext),
      ],
    );
    final row = MedallionRow(
      leading: medallion,
      title: category.name,
      subtitle: categorySubcategoriesMeta(subcategoryCount),
      trailing: trailing,
    );
    final padded = Padding(
      padding: EdgeInsets.only(
        left: indent,
        top: _rowVerticalPadding,
        bottom: _rowVerticalPadding,
      ),
      child: row,
    );

    return Material(
      color: colors.surface,
      child: InkWell(onTap: onTap, child: padded),
    );
  }
}
