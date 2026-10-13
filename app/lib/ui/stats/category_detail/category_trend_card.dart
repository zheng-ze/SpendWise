import 'package:domain/domain.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:spendwise/ui/format/date_format.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/stats/category_detail/category_scope.dart';
import 'package:spendwise/ui/stats/category_detail/trend_line_chart.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

// MARK: - Helpers
String _scopeShortName(
  String mainName,
  CategoryScope scope,
  LedgerState state,
) {
  switch (scope) {
    case AllScope():
    case DirectScope():
      return mainName;
    case SubScope(:final subID):
      return resolvedSubName(subID, state) ?? 'Uncategorized';
  }
}

// MARK: - TrendCard
class TrendCard extends StatefulWidget {
  const TrendCard({
    super.key,
    required this.scope,
    required this.mainCategory,
    required this.state,
    required this.detailDate,
    required this.isYearRange,
    required this.months,
    required this.amounts,
    required this.color,
  });

  final CategoryScope scope;
  final TransactionCategory? mainCategory;
  final LedgerState state;
  final DateTime detailDate;
  final bool isYearRange;
  final List<DateTime> months;
  final List<Decimal> amounts;
  final Color color;

  @override
  State<TrendCard> createState() => _TrendCardState();
}

// MARK: - TrendCardState
class _TrendCardState extends State<TrendCard> {
  int? _selectedIndex;

  static const _chartHeight = 160.0;
  static const _cardSideInset = 16.0;
  static const _cardTopInset = 16.0;
  static const _cardBottomInset = 0.0;
  static const _cardPadding = EdgeInsets.fromLTRB(
    _cardSideInset,
    _cardTopInset,
    _cardSideInset,
    _cardBottomInset,
  );
  static const _cardInnerInset = 16.0;
  static const _cardInnerPadding = EdgeInsets.all(_cardInnerInset);
  static const _chartGap = 12.0;
  static const _emptyChartMaxY = 1.0;

  @override
  void didUpdateWidget(covariant TrendCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scope != widget.scope ||
        oldWidget.detailDate != widget.detailDate ||
        oldWidget.isYearRange != widget.isYearRange) {
      _selectedIndex = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final months = widget.months;
    final amounts = widget.amounts;

    final mainName = widget.mainCategory?.name ?? '';
    final titleName = _scopeShortName(mainName, widget.scope, widget.state);

    final maxAmount = amounts.fold(
      Decimal.zero,
      (max, amount) => amount > max ? amount : max,
    );
    final maxY = maxAmount > Decimal.one
        ? maxAmount.toDouble()
        : _emptyChartMaxY;

    final selected = _selectedIndex;
    final hint = widget.isYearRange ? 'this year' : 'last 6 months';
    final headerRight = selected == null
        ? hint
        : '${formatMonthLabel(months[selected])} · ${formatMoney(amounts[selected])}';
    final header = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('$titleName trend', style: theme.textTheme.titleSmall),
        Text(
          headerRight,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
    final chart = SizedBox(
      key: const ValueKey('categoryDetailTrendChart'),
      height: _chartHeight,
      child: TrendLineChart(
        months: months,
        amounts: amounts,
        maxY: maxY,
        lineColor: widget.color,
        selectedMark: context.colors.selectedMark,
        selected: selected,
        onTouch: _onTrendTouch,
      ),
    );

    return Padding(
      padding: _cardPadding,
      child: Card(
        color: theme.colorScheme.surfaceContainerHighest,
        child: Padding(
          padding: _cardInnerPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              header,
              const SizedBox(height: _chartGap),
              chart,
            ],
          ),
        ),
      ),
    );
  }

  void _onTrendTouch(FlTouchEvent event, LineTouchResponse? response) {
    final spots = response?.lineBarSpots;
    if (!event.isInterestedForInteractions || spots == null || spots.isEmpty) {
      if (event is FlPointerExitEvent) setState(() => _selectedIndex = null);
      return;
    }
    setState(() => _selectedIndex = spots.first.x.round());
  }
}
