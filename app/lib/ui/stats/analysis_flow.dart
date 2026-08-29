import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/common/flow_base.dart';
import 'package:spendwise/ui/format/amount_color.dart';
import 'package:spendwise/ui/stats/analysis_view_model.dart';
import 'package:spendwise/ui/stats/category_detail_screen.dart';
import 'package:spendwise/ui/stats/category_detail_view_model.dart';
import 'package:spendwise/ui/stats/stats_donut.dart';
import 'package:spendwise/ui/stats/stats_legend.dart';
import 'package:spendwise/ui/stats/stats_window.dart';

/// Construct with a `ValueKey` distinct per [kind], one for income and one for expense.
class AnalysisFlow extends FlowBase<AnalysisStep> {
  const AnalysisFlow({
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
  ConsumerState<AnalysisFlow> createState() => _AnalysisFlowState();
}

class _AnalysisFlowState extends FlowBaseState<AnalysisStep, AnalysisFlow> {
  @override
  void Function() subscribeToStep(void Function(AnalysisStep? step) handle) =>
      ref
          .listenManual(
            analysisViewModelProvider(widget.kind),
            (previous, AsyncValue<AnalysisViewState> next) =>
                handle(next.value?.step),
          )
          .close;

  @override
  void handleStep(BuildContext context, AnalysisStep step) {
    switch (step) {
      case CategoryDetailRequested(
        :final mainID,
        :final isYearRange,
        :final initialDate,
      ):
        final route = MaterialPageRoute<void>(
          builder: (_) => CategoryDetailScreen(
            args: CategoryDetailArgs(
              mainID: mainID,
              kind: widget.kind,
              isYearRange: isYearRange,
              initialDate: initialDate,
            ),
          ),
        );
        // Pushes to the root Navigator so the detail screen covers the tab row and month
        // selector this Flow's own nested Navigator sits under.
        Navigator.of(context, rootNavigator: true).push(route);
    }
    ref.read(analysisViewModelProvider(widget.kind).notifier).clearStep();
  }

  @override
  Widget buildRoot(BuildContext context) => _AnalysisBody(
    kind: widget.kind,
    window: widget.window,
    isYearRange: widget.isYearRange,
    selectedDate: widget.selectedDate,
  );
}

class _AnalysisBody extends ConsumerWidget {
  const _AnalysisBody({
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
    final viewModel = ref.watch(analysisViewModelProvider(kind).notifier);

    return asyncState.when(
      data: (viewState) => _AnalysisBodyContent(
        viewState: viewState,
        viewModel: viewModel,
        kind: kind,
        window: window,
        isYearRange: isYearRange,
        selectedDate: selectedDate,
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(child: Text('$error')),
    );
  }
}

class _AnalysisBodyContent extends StatelessWidget {
  const _AnalysisBodyContent({
    required this.viewState,
    required this.viewModel,
    required this.kind,
    required this.window,
    required this.isYearRange,
    required this.selectedDate,
  });

  final AnalysisViewState viewState;
  final AnalysisViewModel viewModel;
  final CategoryKind kind;
  final DateRange window;
  final bool isYearRange;
  final DateTime selectedDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AmountColors.of(theme);

    final categorySlices = analysisSlices(viewState, window);

    var total = Decimal.zero;
    for (final slice in categorySlices) {
      total += slice.amount;
    }

    final label = kind == CategoryKind.income
        ? 'Total income'
        : 'Total expenses';
    final totalColor = kind == CategoryKind.income ? colors.gain : colors.loss;

    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: AmountHeader(
            caption: label,
            amount: total,
            amountColor: totalColor,
          ),
        ),
        if (categorySlices.isEmpty)
          _EmptyState(kind: kind)
        else ...[
          StatsDonut(slices: categorySlices),
          const Divider(height: 1),
          StatsLegend(
            slices: categorySlices,
            onTapCategory: (mainID) => viewModel.requestCategoryDetail(
              mainID: mainID,
              isYearRange: isYearRange,
              initialDate: selectedDate,
            ),
          ),
        ],
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.kind});

  final CategoryKind kind;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final message = kind == CategoryKind.income
        ? 'No income in this period'
        : 'No expense in this period';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(
            Icons.pie_chart_outline,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
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
