import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/common/feedback/async_value_view.dart';
import 'package:spendwise/ui/common/feedback/empty_state.dart';
import 'package:spendwise/ui/common/lists/swipe_row.dart';
import 'package:spendwise/ui/common/navigation/page_header.dart';
import 'package:spendwise/ui/common/navigation/period_stepper.dart';
import 'package:spendwise/ui/format/date_format.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/shell/shell_pane_host.dart';
import 'package:spendwise/ui/transactions/daily_list/day_header.dart';
import 'package:spendwise/ui/transactions/daily_list/day_sections.dart';
import 'package:spendwise/ui/transactions/daily_list/transaction_cell.dart';
import 'package:spendwise/ui/transactions/daily_list/transactions_summary.dart';
import 'package:spendwise/ui/transactions/transactions_flow.dart';
import 'package:spendwise/ui/transactions/trends_detail_action.dart';
import 'package:spendwise/ui/transactions/transactions_view_model.dart';

const _headerHeightFactor = 2.0;
const _pageHorizontalInset = 14.0;
const _periodSummaryGap = 4.0;
const _summaryRegisterGap = 16.0;
const _previousMonthLabel = 'Previous month';
const _nextMonthLabel = 'Next month';

// MARK: - TransactionsScreen
class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({
    super.key,
    this.scope,
    this.onBackPressed,
    this.presentation = ShellPagePresentation.fullPage,
  });

  final TransactionsScope? scope;

  final VoidCallback? onBackPressed;

  final ShellPagePresentation presentation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(shellLayoutModeProvider);
    final async = ref.watch(transactionsViewModelProvider(scope));
    final viewModel = ref.read(transactionsViewModelProvider(scope).notifier);
    final wideComposition =
        presentation == ShellPagePresentation.fullPage &&
        (mode == ShellLayoutMode.open || mode == ShellLayoutMode.desktop);
    return AsyncValueView(
      value: async,
      onRetry: () => ref.invalidate(transactionsViewModelProvider(scope)),
      fullPage: true,
      data: (state) => _TransactionsScreenBody(
        state: state,
        viewModel: viewModel,
        onBackPressed: onBackPressed,
        showsTrendsAction: scope == null,
        wideComposition: wideComposition,
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
  });

  final TransactionsViewState state;
  final TransactionsViewModel viewModel;
  final VoidCallback? onBackPressed;
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
    );
    final trendsAction = showsTrendsAction
        ? TrendsDetailAction(onPressed: viewModel.requestTrends)
        : null;
    final summary = TransactionsSummary(
      net: state.total,
      expenses: state.expenses,
      income: state.income,
      wideComposition: wideComposition,
      bottomSpacing: trendsAction == null ? _summaryRegisterGap : 0,
    );

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
  });

  final String title;
  final DateTime selectedDate;
  final TransactionsViewModel viewModel;
  final VoidCallback? onBackPressed;

  @override
  Widget build(BuildContext context) {
    final heading = PageHeader(title: title, onBack: onBackPressed);
    final period = _PeriodRow(
      selectedDate: selectedDate,
      onPrevious: viewModel.previousMonth,
      onNext: viewModel.nextMonth,
    );

    final paddedPeriod = Padding(
      padding: const EdgeInsets.symmetric(horizontal: _pageHorizontalInset),
      child: period,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        heading,
        paddedPeriod,
        SizedBox(height: _periodSummaryGap),
      ],
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
    return PeriodStepper(
      label: formatMonthLabel(selectedDate),
      previousLabel: _previousMonthLabel,
      nextLabel: _nextMonthLabel,
      onPrevious: onPrevious,
      onNext: onNext,
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
    if (sections.isEmpty) return const _NoTransactions();

    final sectionSlivers = <Widget>[];
    for (var index = 0; index < sections.length; index++) {
      if (index > 0) {
        sectionSlivers.add(
          const SliverToBoxAdapter(child: SizedBox(height: _registerDayGap)),
        );
      }

      final section = sections[index];
      final textScaler = MediaQuery.textScalerOf(context);
      final dayHeader = SliverPersistentHeader(
        pinned: true,
        delegate: DayHeaderDelegate(
          day: section.date,
          net: section.income - section.expenses,
          registerStyle: true,
          textScaler: textScaler,
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

class _NoTransactions extends StatelessWidget {
  const _NoTransactions();

  static const _icon = Icons.inbox_outlined;
  static const _title = 'No transactions';

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: EmptyState(icon: _icon, title: _title),
    );
  }
}
