import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/common/flow_base.dart';
import 'package:spendwise/ui/format/amount_style.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/stats/analysis/analysis_view_model.dart';
import 'package:spendwise/ui/stats/category_detail/category_detail_screen.dart';
import 'package:spendwise/ui/stats/category_detail/category_detail_view_model.dart';
import 'package:spendwise/ui/stats/donut/stats_donut.dart';
import 'package:spendwise/ui/stats/donut/stats_legend.dart';
import 'package:spendwise/ui/stats/helpers/stats_window.dart';

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

  static const _headerPadding = EdgeInsets.all(16);
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

  static const _emptyPadding = EdgeInsets.symmetric(vertical: 48);
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
