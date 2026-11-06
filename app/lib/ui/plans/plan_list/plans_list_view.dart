import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/common/feedback/async_value_view.dart';
import 'package:spendwise/ui/common/feedback/empty_state.dart';
import 'package:spendwise/ui/common/lists/date_badge.dart';
import 'package:spendwise/ui/common/layout/open_split_layout.dart';
import 'package:spendwise/ui/common/lists/medallion_row.dart';
import 'package:spendwise/ui/common/sheets/tray.dart';
import 'package:spendwise/ui/format/amount_style.dart';
import 'package:spendwise/ui/plans/plan_list/plan_list_view_model.dart';
import 'package:spendwise/ui/plans/plan_list/plan_selection.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/shell/shell_sheet_occupancy.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

// MARK: - Constants
const _contentPadding = EdgeInsets.all(12);
const _rowPadding = EdgeInsets.symmetric(vertical: 7);
const _amountGap = 9.0;
const _helperTopGap = 10.0;
const _countFontSize = 11.0;
const _endedFontSize = 10.0;
const _endedWidth = 30.0;
const _trayTitle = 'Next up';
const _endedLabel = 'Ended';
const _helperCopy =
    'To add a plan, add an entry and choose how often it repeats.';
const _loadErrorTitle = "Couldn't load your plans";
const _emptyIcon = Icons.repeat;
const _emptyTitle = 'Make regular entries easier';
const _emptyBody = 'Choose Repeat when adding an entry to create a plan.';

// MARK: - Helpers
bool plansWideComposition({
  required bool wideLayout,
  required bool sheetPresented,
  required bool selectionPresent,
}) => wideLayout && !sheetPresented && !selectionPresent;

// MARK: - PlansRoot
class PlansRoot extends ConsumerWidget {
  const PlansRoot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(planListViewModelProvider);
    final viewModel = ref.watch(planListViewModelProvider.notifier);
    final wideComposition = plansWideComposition(
      wideLayout: ref.watch(shellLayoutModeProvider) != ShellLayoutMode.phone,
      sheetPresented: ref.watch(shellSheetOccupancyProvider).hasSheets,
      selectionPresent: ref.watch(selectedPlanProvider) != null,
    );
    return AsyncValueView(
      value: state,
      onRetry: () => ref.invalidate(planListViewModelProvider),
      errorTitle: _loadErrorTitle,
      data: (viewState) {
        final list = PlansListView(viewState: viewState, viewModel: viewModel);
        if (!wideComposition) return list;
        return OpenSplitLayout(primary: list, secondary: const SizedBox());
      },
    );
  }
}

// MARK: - PlansListView
class PlansListView extends StatelessWidget {
  const PlansListView({
    super.key,
    required this.viewState,
    required this.viewModel,
  });

  final PlanListViewState viewState;
  final PlanListViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final countStyle = TextStyle(
      fontSize: _countFontSize,
      color: colors.subtext,
    );
    final helperStyle = Theme.of(context).textTheme.bodySmall;
    final rows = [
      for (final row in viewState.rows)
        _PlanRow(row: row, onTap: () => viewModel.selectPlan(row.id)),
    ];
    final tray = Tray(
      title: _trayTitle,
      trailing: Text(viewState.countLabel, style: countStyle),
      child: Column(children: rows),
    );
    final helper = Text(_helperCopy, style: helperStyle);
    const emptyState = EmptyState(
      icon: _emptyIcon,
      title: _emptyTitle,
      body: _emptyBody,
    );
    return ListView(
      padding: _contentPadding,
      children: [
        if (rows.isEmpty)
          emptyState
        else ...[
          tray,
          const SizedBox(height: _helperTopGap),
          helper,
        ],
      ],
    );
  }
}

// MARK: - PlanRow
class _PlanRow extends StatelessWidget {
  const _PlanRow({required this.row, required this.onTap});

  final PlanRowView row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final day = row.day;
    final month = row.month;
    final leading = day == null || month == null
        ? SizedBox(
            width: _endedWidth,
            child: Text(
              _endedLabel,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: _endedFontSize, color: colors.subtext),
            ),
          )
        : DateBadge(day: day, month: month);
    final amountStyle = context.text.small.copyWith(
      color: AmountStyle.of(context, kind: row.kind).color,
    );
    final amount = Padding(
      padding: const EdgeInsets.only(left: _amountGap),
      child: Text(row.amount, style: amountStyle),
    );
    final content = MedallionRow(
      leading: leading,
      title: row.name,
      subtitle: row.caption,
      trailing: amount,
    );
    return InkWell(
      key: ValueKey('plan-${row.id}'),
      onTap: onTap,
      child: Padding(padding: _rowPadding, child: content),
    );
  }
}
