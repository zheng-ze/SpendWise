import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ui/common/lists/swipe_row.dart';
import 'package:spendwise/ui/common/navigation/labelled_back_button.dart';
import 'package:spendwise/ui/format/amount_style.dart';
import 'package:spendwise/ui/format/date_format.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';
import 'package:spendwise/ui/transactions/daily_list/day_header.dart';
import 'package:spendwise/ui/transactions/daily_list/day_sections.dart';
import 'package:spendwise/ui/transactions/daily_list/empty_state.dart';
import 'package:spendwise/ui/transactions/daily_list/transaction_cell.dart';
import 'package:spendwise/ui/transactions/transactions_flow.dart';
import 'package:spendwise/ui/transactions/trends_detail_action.dart';
import 'package:spendwise/ui/transactions/transactions_view_model.dart';

const _headerHeightFactor = 2.0;
const _pageHorizontalInset = 14.0;
const _headerTopInset = 12.0;
const _headingPeriodGap = 14.0;
const _periodSummaryGap = 4.0;
const _headingFontFamily = 'InstrumentSans';
const _headingFontSize = 26.0;
const _headingWeight = FontWeight.w600;
const _headingLetterSpacing = -0.7;
const _periodHitExtent = 48.0;
const _periodArrowExtent = 28.0;
const _periodArrowRadius = 8.0;
const _periodArrowElevation = 1.0;
const _periodArrowIconSize = 18.0;
const _periodLabelFontSize = 12.0;
const _periodLabelWeight = FontWeight.w600;
const _previousMonthLabel = 'Previous month';
const _nextMonthLabel = 'Next month';
const _netLabel = 'Net';
const _spentLabel = 'Spent';
const _incomeLabel = 'Income';
const _summaryRadius = 14.0;
const _summaryBorderWidth = 1.0;
const _summaryHorizontalPadding = 12.0;
const _summaryVerticalPadding = 10.0;
const _summaryColumnGap = 6.0;
const _summaryStackGap = 4.0;
const _summaryLabelFontSize = 10.0;
const _summaryLabelAmountGap = 2.0;
const _summaryAmountFontSize = 12.0;
const _summaryAmountWeight = FontWeight.w600;
const _summaryLeadFontSize = 18.0;
const _summaryLeadWeight = FontWeight.w500;
const _summaryLeadLetterSpacing = -0.3;
const _summaryFlexScale = 100.0;

// MARK: - TransactionsScreen
class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({
    super.key,
    this.scope,
    this.onBackPressed,
    this.backLabel,
  });

  final TransactionsScope? scope;

  final VoidCallback? onBackPressed;

  final String? backLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledger = ref.watch(ledgerProvider);
    if (ledger == null) return const SizedBox.shrink();

    final mode = ref.watch(shellLayoutModeProvider);
    final async = ref.watch(transactionsViewModelProvider(scope));
    final viewModel = ref.read(transactionsViewModelProvider(scope).notifier);

    return async.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(body: Center(child: Text('$error'))),
      data: (state) => _TransactionsScreenBody(
        state: state,
        viewModel: viewModel,
        onBackPressed: onBackPressed,
        backLabel: backLabel,
        showsTrendsAction: scope == null,
        wideComposition:
            mode == ShellLayoutMode.open || mode == ShellLayoutMode.desktop,
      ),
    );
  }
}

// MARK: - TransactionsScreenBody
class _TransactionsScreenBody extends StatelessWidget {
  const _TransactionsScreenBody({
    required this.state,
    required this.viewModel,
    required this.showsTrendsAction,
    required this.wideComposition,
    this.onBackPressed,
    this.backLabel,
  });

  final TransactionsViewState state;
  final TransactionsViewModel viewModel;
  final VoidCallback? onBackPressed;
  final String? backLabel;
  final bool showsTrendsAction;
  final bool wideComposition;

  @override
  Widget build(BuildContext context) {
    final content = _DailyContent(state: state, viewModel: viewModel);
    final header = _TransactionsHeader(
      title: state.title,
      selectedDate: state.selectedDate,
      viewModel: viewModel,
      onBackPressed: onBackPressed,
      backLabel: backLabel,
    );
    final summary = _TotalsBand(state: state, wideComposition: wideComposition);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final headerMaxHeight = constraints.maxHeight / _headerHeightFactor;
            final headerContent = Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                header,
                summary,
                if (showsTrendsAction)
                  TrendsDetailAction(onPressed: viewModel.requestTrends),
              ],
            );
            final scrollableHeader = CustomScrollView(
              primary: false,
              shrinkWrap: true,
              slivers: [SliverToBoxAdapter(child: headerContent)],
            );
            return Column(
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: headerMaxHeight),
                  child: scrollableHeader,
                ),
                Expanded(child: content),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TransactionsHeader extends StatelessWidget {
  const _TransactionsHeader({
    required this.title,
    required this.selectedDate,
    required this.viewModel,
    this.onBackPressed,
    this.backLabel,
  });

  final String title;
  final DateTime selectedDate;
  final TransactionsViewModel viewModel;
  final VoidCallback? onBackPressed;
  final String? backLabel;

  @override
  Widget build(BuildContext context) {
    final titleStyle = TextStyle(
      fontFamily: _headingFontFamily,
      fontSize: _headingFontSize,
      fontWeight: _headingWeight,
      letterSpacing: _headingLetterSpacing,
      color: context.colors.text,
    );
    final heading = Padding(
      padding: const EdgeInsets.symmetric(horizontal: _pageHorizontalInset),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(title, style: titleStyle),
      ),
    );
    final back = onBackPressed;
    final backRow = back == null
        ? null
        : Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: _pageHorizontalInset,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: LabelledBackButton(onPressed: back, label: backLabel),
            ),
          );
    final period = _PeriodRow(
      selectedDate: selectedDate,
      onPrevious: viewModel.previousMonth,
      onNext: viewModel.nextMonth,
    );

    return Padding(
      padding: const EdgeInsets.only(top: _headerTopInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ?backRow,
          heading,
          SizedBox(height: _headingPeriodGap),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: _pageHorizontalInset,
            ),
            child: period,
          ),
          SizedBox(height: _periodSummaryGap),
        ],
      ),
    );
  }
}

class _PeriodRow extends StatelessWidget {
  const _PeriodRow({
    required this.selectedDate,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime selectedDate;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final labelStyle = TextStyle(
      fontSize: _periodLabelFontSize,
      fontWeight: _periodLabelWeight,
      color: context.colors.text,
    );
    return Row(
      children: [
        _PeriodArrow(
          label: _previousMonthLabel,
          icon: Icons.chevron_left,
          onPressed: onPrevious,
        ),
        Expanded(
          child: Center(
            child: Text(formatMonthLabel(selectedDate), style: labelStyle),
          ),
        ),
        _PeriodArrow(
          label: _nextMonthLabel,
          icon: Icons.chevron_right,
          onPressed: onNext,
        ),
      ],
    );
  }
}

class _PeriodArrow extends StatelessWidget {
  const _PeriodArrow({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return IconButton(
      tooltip: label,
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(
        minWidth: _periodHitExtent,
        minHeight: _periodHitExtent,
      ),
      icon: Material(
        color: colors.surface,
        elevation: _periodArrowElevation,
        borderRadius: BorderRadius.circular(_periodArrowRadius),
        child: SizedBox(
          width: _periodArrowExtent,
          height: _periodArrowExtent,
          child: Icon(icon, size: _periodArrowIconSize, color: colors.action),
        ),
      ),
    );
  }
}

class _TotalsBand extends StatelessWidget {
  const _TotalsBand({required this.state, required this.wideComposition});

  final TransactionsViewState state;
  final bool wideComposition;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _summaryMetric(
        context,
        label: _netLabel,
        amount: state.total,
        kind: null,
        isLead: true,
      ),
      _summaryMetric(
        context,
        label: _spentLabel,
        amount: state.expenses,
        kind: AmountKind.expense,
      ),
      _summaryMetric(
        context,
        label: _incomeLabel,
        amount: state.income,
        kind: AmountKind.income,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _pageHorizontalInset),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth =
              constraints.maxWidth -
              (_summaryHorizontalPadding * 2) -
              (_summaryBorderWidth * 2);
          final widths = metrics
              .map((metric) => _metricRequiredWidth(context, metric))
              .toList();
          final allFit = _rowFits(
            widths,
            availableWidth,
            gap: _summaryColumnGap,
          );
          final supportingValuesFit = _rowFits(
            widths.skip(1).toList(),
            availableWidth,
            gap: _summaryColumnGap,
          );
          final content = _totalsContent(
            metrics,
            widths,
            wideComposition && allFit,
            supportingValuesFit,
          );
          return Container(
            decoration: BoxDecoration(
              color: context.colors.surface,
              border: Border.all(
                color: context.colors.edge,
                width: _summaryBorderWidth,
              ),
              borderRadius: BorderRadius.circular(_summaryRadius),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: _summaryHorizontalPadding,
              vertical: _summaryVerticalPadding,
            ),
            child: content,
          );
        },
      ),
    );
  }
}

typedef _SummaryMetricData = ({String label, String value, TextStyle style});

_SummaryMetricData _summaryMetric(
  BuildContext context, {
  required String label,
  required Decimal amount,
  required AmountKind? kind,
  bool isLead = false,
}) {
  final style = TextStyle(
    fontSize: isLead ? _summaryLeadFontSize : _summaryAmountFontSize,
    fontWeight: isLead ? _summaryLeadWeight : _summaryAmountWeight,
    letterSpacing: isLead ? _summaryLeadLetterSpacing : null,
    color: AmountStyle.of(context, kind: kind, signedValue: amount).color,
  );
  return (
    label: label,
    value: formatSignedMoney(amount, kind: kind),
    style: style,
  );
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.metric});

  final _SummaryMetricData metric;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      metric.label,
      style: TextStyle(
        fontSize: _summaryLabelFontSize,
        color: context.colors.subtext,
      ),
    );
    final value = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Text(
        metric.value,
        maxLines: 1,
        softWrap: false,
        style: metric.style,
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        label,
        SizedBox(height: _summaryLabelAmountGap),
        value,
      ],
    );
  }
}

List<Widget> _metricRow(List<_SummaryMetricData> metrics, List<double> widths) {
  return [
    for (var index = 0; index < metrics.length; index++) ...[
      if (index > 0) SizedBox(width: _summaryColumnGap),
      Expanded(
        flex: (widths[index] * _summaryFlexScale).round(),
        child: _SummaryMetric(metric: metrics[index]),
      ),
    ],
  ];
}

Widget _totalsContent(
  List<_SummaryMetricData> metrics,
  List<double> widths,
  bool useWideRow,
  bool supportingValuesFit,
) {
  if (useWideRow) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: _metricRow(metrics, widths),
    );
  }
  if (!supportingValuesFit) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < metrics.length; index++) ...[
          if (index > 0) SizedBox(height: _summaryStackGap),
          _SummaryMetric(metric: metrics[index]),
        ],
      ],
    );
  }
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _SummaryMetric(metric: metrics.first),
      SizedBox(height: _summaryStackGap),
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: _metricRow(metrics.skip(1).toList(), widths.skip(1).toList()),
      ),
    ],
  );
}

double _metricRequiredWidth(BuildContext context, _SummaryMetricData metric) {
  final labelWidth = _textWidth(
    context,
    metric.label,
    TextStyle(fontSize: _summaryLabelFontSize, color: context.colors.subtext),
  );
  final valueWidth = _textWidth(context, metric.value, metric.style);
  return labelWidth > valueWidth ? labelWidth : valueWidth;
}

double _textWidth(BuildContext context, String value, TextStyle style) {
  final effectiveStyle = DefaultTextStyle.of(context).style.merge(style);
  final painter = TextPainter(
    text: TextSpan(text: value, style: effectiveStyle),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  return painter.width;
}

bool _rowFits(
  List<double> widths,
  double availableWidth, {
  required double gap,
}) {
  final requiredWidth =
      widths.fold<double>(0, (total, width) => total + width) +
      gap * (widths.length - 1);
  return requiredWidth <= availableWidth;
}

// MARK: - DailyContent
class _DailyContent extends StatelessWidget {
  const _DailyContent({required this.state, required this.viewModel});

  final TransactionsViewState state;
  final TransactionsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final sections = state.daySections;
    if (sections.isEmpty) return const TransactionsEmptyState();

    return CustomScrollView(
      slivers: [
        for (final section in sections)
          SliverMainAxisGroup(
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: DayHeaderDelegate(
                  day: section.date,
                  net: section.income - section.expenses,
                ),
              ),
              _DaySliverList(section: section, viewModel: viewModel),
            ],
          ),
      ],
    );
  }
}

// MARK: - DaySliverList
class _DaySliverList extends StatelessWidget {
  const _DaySliverList({required this.section, required this.viewModel});

  final DaySection section;
  final TransactionsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return SliverList.builder(
      itemCount: section.rows.length,
      itemBuilder: (context, index) {
        final row = section.rows[index];
        final cell = TransactionCell(
          row: row,
          onTap: () => viewModel.openEntry(row.id),
        );

        return SwipeRow(
          itemKey: ValueKey(row.id),
          itemName: row.title,
          onDeleted: () => viewModel.deleteEntry(row.id),
          child: cell,
        );
      },
    );
  }
}
