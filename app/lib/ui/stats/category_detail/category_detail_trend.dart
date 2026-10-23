import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/common/lists/flat_entry_sliver.dart';
import 'package:spendwise/ui/common/sheets/sliver_tray.dart';
import 'package:spendwise/ui/stats/category_detail/category_detail_view_model.dart';
import 'package:spendwise/ui/stats/trends/trends_controls.dart';
import 'package:spendwise/ui/stats/trends/trends_intent.dart';
import 'package:spendwise/ui/stats/trends/trends_period_card.dart';

const _monthlyTrendTitle = 'Monthly trend';
const _yearlyTrendTitle = 'Yearly trend';
const _emptySelectionMessage = 'No entries in this period';
const _emptySelectionPadding = EdgeInsets.symmetric(vertical: 20);

class CategoryDetailTrend extends StatelessWidget {
  const CategoryDetailTrend({
    super.key,
    required this.trend,
    required this.viewModel,
    required this.ledger,
    required this.state,
  });

  final CategoryDetailTrendBody trend;
  final CategoryDetailViewModel viewModel;
  final Ledger ledger;
  final LedgerState state;

  @override
  Widget build(BuildContext context) {
    final modeControl = TrendsModeControl(
      value: trend.mode,
      onChanged: viewModel.setTrendMode,
    );
    final periodRow = TrendsPeriodRowView(
      period: trend.period,
      onPrevious: viewModel.previousTrendPage,
      onNext: viewModel.nextTrendPage,
    );
    final chart = TrendsChart(
      bars: trend.bars,
      selectedIndex: trend.selectedIndex,
      onSelect: viewModel.selectTrendSlot,
    );
    final selection = trend.selection;
    final resultSlivers = selection == null
        ? const <Widget>[]
        : _selectionSlivers(selection);
    final slivers = <Widget>[
      SliverToBoxAdapter(child: modeControl),
      SliverToBoxAdapter(child: periodRow),
      SliverToBoxAdapter(child: chart),
      ...resultSlivers,
    ];
    final title = trend.mode == TrendsMode.month
        ? _monthlyTrendTitle
        : _yearlyTrendTitle;
    return SliverTray(title: title, slivers: slivers);
  }

  List<Widget> _selectionSlivers(CategoryDetailTrendSelection selection) {
    final entries = selection.rows.isEmpty
        ? const SliverToBoxAdapter(
            child: Padding(
              padding: _emptySelectionPadding,
              child: Text(_emptySelectionMessage),
            ),
          )
        : FlatEntrySliver(rows: selection.rows, ledger: ledger, state: state);
    return [
      SliverToBoxAdapter(
        child: TrendsHeadlineView(headline: selection.headline),
      ),
      entries,
    ];
  }
}
