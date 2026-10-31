import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/charts/month_bars.dart';

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
    required this.barColor,
  });

  final List<DateTime> months;
  final List<MonthBarSlot> slots;
  final Decimal limit;
  final double maxY;
  final DateTime selectedMonth;
  final void Function(DateTime month) onSelectMonth;
  final Color barColor;

  static const _chartPadding = EdgeInsets.fromLTRB(16, 0, 16, 0);
  static const _noSelection = -1;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = months.indexWhere(
      (month) =>
          month.year == selectedMonth.year &&
          month.month == selectedMonth.month,
    );
    final chart = MonthBars(
      slots: slots,
      months: months,
      limit: limit.toDouble(),
      maxValue: maxY,
      barColor: barColor,
      touchFullHeight: true,
      selectedIndex: selectedIndex == _noSelection ? null : selectedIndex,
      onSelect: (index) => onSelectMonth(months[index]),
      height: double.infinity,
    );

    return Padding(padding: _chartPadding, child: chart);
  }
}
