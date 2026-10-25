import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ui/common/lists/swipe_row.dart';
import 'package:spendwise/ui/common/navigation/labelled_back_button.dart';
import 'package:spendwise/ui/format/date_format.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';
import 'package:spendwise/ui/transactions/daily_list/day_header.dart';
import 'package:spendwise/ui/transactions/daily_list/day_sections.dart';
import 'package:spendwise/ui/transactions/daily_list/empty_state.dart';
import 'package:spendwise/ui/transactions/daily_list/transaction_cell.dart';
import 'package:spendwise/ui/transactions/daily_list/transactions_summary.dart';
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
    final summary = TransactionsSummary(
      net: state.total,
      expenses: state.expenses,
      income: state.income,
      wideComposition: wideComposition,
    );
    final trendsAction = showsTrendsAction
        ? TrendsDetailAction(onPressed: viewModel.requestTrends)
        : null;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: _TransactionsReadyLayout(
          header: header,
          summary: summary,
          trendsAction: trendsAction,
          content: content,
        ),
      ),
    );
  }
}

class _TransactionsReadyLayout extends StatelessWidget {
  const _TransactionsReadyLayout({
    required this.header,
    required this.summary,
    required this.content,
    this.trendsAction,
  });

  final Widget header;
  final Widget summary;
  final Widget content;
  final Widget? trendsAction;

  @override
  Widget build(BuildContext context) {
    final headerChildren = [header, summary];
    final action = trendsAction;
    if (action != null) headerChildren.add(action);
    final headerContent = Column(
      mainAxisSize: MainAxisSize.min,
      children: headerChildren,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final headerMaxHeight = constraints.maxHeight / _headerHeightFactor;
        final headerConstraints = BoxConstraints(maxHeight: headerMaxHeight);
        final headerSliver = SliverToBoxAdapter(child: headerContent);
        final headerScrollView = CustomScrollView(
          primary: false,
          shrinkWrap: true,
          slivers: [headerSliver],
        );
        final constrainedHeader = ConstrainedBox(
          constraints: headerConstraints,
          child: headerScrollView,
        );
        final expandedContent = Expanded(child: content);
        final children = [constrainedHeader, expandedContent];
        return Column(children: children);
      },
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
    final monthLabel = Text(formatMonthLabel(selectedDate), style: labelStyle);
    return Row(
      children: [
        _PeriodArrow(
          label: _previousMonthLabel,
          icon: Icons.chevron_left,
          onPressed: onPrevious,
        ),
        Expanded(child: Center(child: monthLabel)),
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

// MARK: - DailyContent
class _DailyContent extends StatelessWidget {
  const _DailyContent({required this.state, required this.viewModel});

  final TransactionsViewState state;
  final TransactionsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final sections = state.daySections;
    if (sections.isEmpty) return const TransactionsEmptyState();

    final sectionSlivers = <Widget>[];
    for (var index = 0; index < sections.length; index++) {
      if (index > 0) {
        sectionSlivers.add(
          const SliverToBoxAdapter(child: SizedBox(height: _registerDayGap)),
        );
      }

      final section = sections[index];
      final dayHeader = SliverPersistentHeader(
        pinned: true,
        delegate: DayHeaderDelegate(
          day: section.date,
          net: section.income - section.expenses,
          registerStyle: true,
        ),
      );
      final entries = _DaySliverList(section: section, viewModel: viewModel);
      sectionSlivers.add(SliverMainAxisGroup(slivers: [dayHeader, entries]));
    }

    return CustomScrollView(slivers: sectionSlivers);
  }
}

const _registerDayGap = 10.0;

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
        final cell = TransactionCell.register(
          row: row,
          onTap: () => viewModel.openEntry(row.id),
          isLastInDay: index == section.rows.length - 1,
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
