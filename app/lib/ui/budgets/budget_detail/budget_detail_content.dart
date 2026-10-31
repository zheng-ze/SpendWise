import 'package:flutter/material.dart';

import 'package:spendwise/ui/budgets/budget_detail/budget_counted_entry_list.dart';
import 'package:spendwise/ui/budgets/budget_detail/budget_detail_chart.dart';
import 'package:spendwise/ui/budgets/budget_detail/budget_detail_presentation.dart';
import 'package:spendwise/ui/budgets/budget_detail/budget_detail_view_model.dart';
import 'package:spendwise/ui/common/buttons/app_buttons.dart';
import 'package:spendwise/ui/common/feedback/empty_state.dart';
import 'package:spendwise/ui/common/feedback/loading_skeleton.dart';
import 'package:spendwise/ui/common/inputs/month_year_selector.dart';
import 'package:spendwise/ui/common/sheets/tray.dart';
import 'package:spendwise/ui/format/amount_style.dart';
import 'package:spendwise/ui/format/date_format.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/stats/helpers/amount_header.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

// MARK: - Constants
const _contentPadding = EdgeInsets.all(12);
const _sectionGap = 10.0;
const _chartHeight = 220.0;
const _progressGap = 10.0;
const _progressHeight = 7.0;
const _progressRadius = 4.0;
const _chartGap = 8.0;
const _entriesLabelPadding = EdgeInsets.fromLTRB(4, 16, 4, 8);
const _entriesSuffix = ' ENTRIES';
const _emptyIcon = Icons.receipt_long_outlined;
const _failureTitle = "Couldn't load this budget";
const _retryLabel = 'Try again';
const _deletedText = 'Budget deleted';
const _failureGap = 8.0;

// MARK: - BudgetDetailContent
class BudgetDetailContent extends StatelessWidget {
  const BudgetDetailContent({
    super.key,
    required this.viewState,
    required this.viewModel,
  });

  final BudgetDetailViewState viewState;
  final BudgetDetailViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final presentation = budgetDetailPresentation(viewState);
    if (presentation.body == BudgetDetailBody.deleted) {
      return const Padding(
        padding: _contentPadding,
        child: Center(child: Text(_deletedText)),
      );
    }

    final failure = presentation.failure;
    final projection = viewState.projection;
    final summary = presentation.summary;
    final failureTray = failure == null
        ? null
        : _FailureTray(reason: failure, onRetry: viewModel.retry);

    final Widget body;
    if (projection != null && summary != null) {
      body = _PopulatedContent(
        viewState: viewState,
        projection: projection,
        summary: summary,
        presentation: presentation,
        viewModel: viewModel,
      );
    } else if (presentation.body == BudgetDetailBody.skeleton) {
      body = const LoadingTrays();
    } else {
      body = const SizedBox.shrink();
    }

    return Padding(
      padding: _contentPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (failureTray != null) ...[
            failureTray,
            const SizedBox(height: _failureGap),
          ],
          body,
        ],
      ),
    );
  }
}

// MARK: - Populated
class _PopulatedContent extends StatelessWidget {
  const _PopulatedContent({
    required this.viewState,
    required this.projection,
    required this.summary,
    required this.presentation,
    required this.viewModel,
  });

  final BudgetDetailViewState viewState;
  final BudgetDetailProjection projection;
  final BudgetDetailSummaryValues summary;
  final BudgetDetailPresentation presentation;
  final BudgetDetailViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final summaryTray = _SummaryTray(summary: summary);
    final chartTray = _ChartTray(
      viewState: viewState,
      projection: projection,
      viewModel: viewModel,
    );
    final entries = _EntriesSection(
      viewState: viewState,
      emptyCopy: presentation.emptyCopy,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        summaryTray,
        const SizedBox(height: _sectionGap),
        chartTray,
        const SizedBox(height: _sectionGap),
        entries,
      ],
    );
  }
}

// MARK: - Summary
class _SummaryTray extends StatelessWidget {
  const _SummaryTray({required this.summary});

  final BudgetDetailSummaryValues summary;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final amountColor = summary.overLimit
        ? AmountStyle.of(context, kind: AmountKind.expense).color
        : Theme.of(context).colorScheme.onSurface;
    final header = AmountHeader(
      caption: '${formatMoney(summary.spent)} of ${formatMoney(summary.limit)}',
      amount: summary.remaining,
      amountColor: amountColor,
    );
    final progress = LinearProgressIndicator(
      value: summary.progress,
      minHeight: _progressHeight,
      borderRadius: BorderRadius.circular(_progressRadius),
      color: summary.overLimit ? colors.error : colors.action,
      backgroundColor: colors.tint,
    );

    return Tray(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          const SizedBox(height: _progressGap),
          progress,
        ],
      ),
    );
  }
}

// MARK: - Chart
class _ChartTray extends StatelessWidget {
  const _ChartTray({
    required this.viewState,
    required this.projection,
    required this.viewModel,
  });

  final BudgetDetailViewState viewState;
  final BudgetDetailProjection projection;
  final BudgetDetailViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final selector = Center(
      child: MonthYearSelector(
        value: viewState.displayedYear,
        step: MonthYearStep.year,
        onChanged: viewModel.changeYear,
      ),
    );
    final chart = SizedBox(
      height: _chartHeight,
      child: BudgetDetailChart(
        months: projection.months,
        slots: budgetMonthBarSlots(projection.slots),
        limit: projection.limit,
        maxY: projection.chartMaxYValue,
        selectedMonth: viewState.selectedMonth,
        onSelectMonth: viewModel.selectMonth,
        barColor: AmountStyle.of(context, kind: AmountKind.expense).color,
      ),
    );

    return Tray(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          selector,
          const SizedBox(height: _chartGap),
          chart,
        ],
      ),
    );
  }
}

// MARK: - Entries
class _EntriesSection extends StatelessWidget {
  const _EntriesSection({required this.viewState, required this.emptyCopy});

  final BudgetDetailViewState viewState;
  final BudgetDetailEmptyCopy? emptyCopy;

  @override
  Widget build(BuildContext context) {
    final copy = emptyCopy;
    if (copy != null) {
      return EmptyState(icon: _emptyIcon, title: copy.title, body: copy.body);
    }

    final theme = Theme.of(context);
    final label = Padding(
      padding: _entriesLabelPadding,
      child: Text(
        '${formatMonthLabel(viewState.selectedMonth).toUpperCase()}$_entriesSuffix',
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
    final entryList = BudgetCountedEntryList(
      ledger: viewState.ledger,
      state: viewState.ledgerState,
      counted: viewState.countedEntries,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [label, entryList],
    );
  }
}

// MARK: - Failure
class _FailureTray extends StatelessWidget {
  const _FailureTray({required this.reason, required this.onRetry});

  final Object reason;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Tray(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(_failureTitle),
          Text('$reason'),
          PrimaryButton(label: _retryLabel, onPressed: onRetry),
        ],
      ),
    );
  }
}
