import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/format/amount_style.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/stats/analysis/analysis_view_model.dart';
import 'package:spendwise/ui/stats/donut/stats_donut.dart';
import 'package:spendwise/ui/stats/donut/stats_legend.dart';
import 'package:spendwise/ui/stats/helpers/stats_window.dart';
import 'package:spendwise/ui/stats/stats_root_view_model.dart';

// MARK: - AnalysisBody
class AnalysisBody extends ConsumerWidget {
  const AnalysisBody({
    super.key,
    required this.kind,
    required this.window,
    required this.isYearRange,
    required this.selectedDate,
  });

  final CategoryKind kind;
  final DateRange window;
  final bool isYearRange;
  final DateTime selectedDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(analysisViewModelProvider(kind));
    final statsViewModel = ref.read(statsRootViewModelProvider.notifier);
    void openCategoryDetail(String mainID) =>
        statsViewModel.requestCategoryDetail(
          kind: kind,
          mainID: mainID,
          isYearRange: isYearRange,
          initialDate: selectedDate,
        );

    return asyncState.when(
      data: (viewState) => _AnalysisBodyContent(
        viewState: viewState,
        onCategoryTap: openCategoryDetail,
        kind: kind,
        window: window,
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(child: Text('$error')),
    );
  }
}

// MARK: - AnalysisBodyContent
class _AnalysisBodyContent extends StatelessWidget {
  const _AnalysisBodyContent({
    required this.viewState,
    required this.onCategoryTap,
    required this.kind,
    required this.window,
  });

  final AnalysisViewState viewState;
  final ValueChanged<String> onCategoryTap;
  final CategoryKind kind;
  final DateRange window;

  static const _headerInset = 16.0;
  static const _headerPadding = EdgeInsets.all(_headerInset);
  static const _dividerHeight = 1.0;

  @override
  Widget build(BuildContext context) {
    final style = AmountStyle.of(
      context,
      kind: kind == CategoryKind.income
          ? AmountKind.income
          : AmountKind.expense,
    );

    final categorySlices = analysisSlices(viewState, window);

    var total = Decimal.zero;
    for (final slice in categorySlices) {
      total += slice.amount;
    }

    final label = kind == CategoryKind.income
        ? 'Total income'
        : 'Total expenses';
    final totalColor = style.color;
    final header = Padding(
      padding: _headerPadding,
      child: AmountHeader(
        caption: label,
        amount: total,
        amountColor: totalColor,
      ),
    );

    return ListView(
      children: [
        header,
        if (categorySlices.isEmpty)
          _EmptyState(kind: kind)
        else ...[
          StatsDonut(slices: categorySlices),
          const Divider(height: _dividerHeight),
          StatsLegend(slices: categorySlices, onTapCategory: onCategoryTap),
        ],
      ],
    );
  }
}

// MARK: - EmptyState
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.kind});

  final CategoryKind kind;

  static const _emptyVerticalInset = 48.0;
  static const _emptyPadding = EdgeInsets.symmetric(
    vertical: _emptyVerticalInset,
  );
  static const _emptyIconSize = 48.0;
  static const _messageGap = 12.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final message = kind == CategoryKind.income
        ? 'No income in this period'
        : 'No expense in this period';

    return Padding(
      padding: _emptyPadding,
      child: Column(
        children: [
          Icon(
            Icons.pie_chart_outline,
            size: _emptyIconSize,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: _messageGap),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
