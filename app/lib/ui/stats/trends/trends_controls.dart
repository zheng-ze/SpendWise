import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/inputs/segmented_control.dart';
import 'package:spendwise/ui/common/navigation/period_stepper.dart';
import 'package:spendwise/ui/stats/trends/trends_body.dart';
import 'package:spendwise/ui/stats/trends/trends_intent.dart';

// MARK: - Constants
const _expenseLabel = 'Expense';
const _incomeLabel = 'Income';
const _monthLabel = 'Month by month';
const _yearLabel = 'Year by year';
const _controlGap = 10.0;

// MARK: - KindControl
class TrendsKindControl extends StatelessWidget {
  const TrendsKindControl({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final TrendsKind value;
  final ValueChanged<TrendsKind> onChanged;

  @override
  Widget build(BuildContext context) {
    const options = [
      SegmentedOption(value: TrendsKind.expense, label: _expenseLabel),
      SegmentedOption(value: TrendsKind.income, label: _incomeLabel),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: _controlGap),
      child: SegmentedControl<TrendsKind>(
        options: options,
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}

// MARK: - ModeControl
class TrendsModeControl extends StatelessWidget {
  const TrendsModeControl({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final TrendsMode value;
  final ValueChanged<TrendsMode> onChanged;

  @override
  Widget build(BuildContext context) {
    const options = [
      SegmentedOption(value: TrendsMode.month, label: _monthLabel),
      SegmentedOption(value: TrendsMode.year, label: _yearLabel),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: _controlGap),
      child: SegmentedControl<TrendsMode>(
        options: options,
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}

// MARK: - PeriodRow
class TrendsPeriodRowView extends StatelessWidget {
  const TrendsPeriodRowView({
    super.key,
    required this.period,
    required this.onPrevious,
    required this.onNext,
  });

  final TrendsPeriodRow period;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  static const _verticalMargin = EdgeInsets.only(top: 2, bottom: 4);

  @override
  Widget build(BuildContext context) {
    final stepper = PeriodStepper(
      label: period.rangeLabel,
      previousEnabled: period.previousEnabled,
      nextEnabled: period.nextEnabled,
      onPrevious: onPrevious,
      onNext: onNext,
    );
    return Padding(padding: _verticalMargin, child: stepper);
  }
}
