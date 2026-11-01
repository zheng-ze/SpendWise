import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/charts/month_bar_chart.dart';
import 'package:spendwise/ui/common/charts/month_bars.dart';
import 'package:spendwise/ui/format/date_format.dart';

// MARK: - Chart

class BudgetDetailChart extends StatelessWidget {
  const BudgetDetailChart({
    super.key,
    required this.months,
    required this.slots,
    required this.limit,
    required this.maxY,
    required this.selectedMonth,
    required this.onSelectMonth,
  });

  final List<DateTime> months;
  final List<MonthBarSlot> slots;
  final Decimal limit;
  final double maxY;
  final DateTime selectedMonth;
  final void Function(DateTime month) onSelectMonth;

  static const _barsHeight = 160.0;
  static const _noSelection = -1;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = months.indexWhere(
      (month) =>
          month.year == selectedMonth.year &&
          month.month == selectedMonth.month,
    );
    final columns = [
      for (var i = 0; i < months.length; i++)
        MonthBarColumn(
          slot: slots[i],
          label: formatMonthInitial(months[i]),
          semanticLabel: formatMonthNameYear(months[i]),
        ),
    ];
    return MonthBarChart(
      columns: columns,
      limit: limit.toDouble(),
      maxValue: maxY,
      barsHeight: _barsHeight,
      selectedIndex: selectedIndex == _noSelection ? null : selectedIndex,
      onSelect: (index) => onSelectMonth(months[index]),
    );
  }
}
