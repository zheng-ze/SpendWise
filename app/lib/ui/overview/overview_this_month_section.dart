import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/feedback/loading_skeleton.dart';
import 'package:spendwise/ui/common/sheets/tray.dart';
import 'package:spendwise/ui/overview/overview_constants.dart';
import 'package:spendwise/ui/overview/overview_rows.dart';
import 'package:spendwise/ui/overview/overview_view_model.dart';
import 'package:spendwise/ui/theme/spendwise_colors.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

// MARK: - Tray

class ThisMonthTray extends StatelessWidget {
  const ThisMonthTray({
    super.key,
    required this.month,
    required this.failed,
    required this.onRetry,
  });

  final OverviewThisMonth? month;
  final bool failed;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final month = this.month;
    final figures = month?.figures;
    final Widget content;
    if (failed) {
      content = OverviewLoadError(
        message: overviewThisMonthErrorTitle,
        onRetry: onRetry,
      );
    } else if (month == null) {
      content = const LoadingSkeleton();
    } else if (figures == null) {
      content = const OverviewEmptyCopy(overviewThisMonthEmpty);
    } else {
      content = ThisMonthFigures(caption: month.caption, figures: figures);
    }
    return SizedBox(
      width: overviewFullWidth,
      child: Tray(title: overviewThisMonthTitle, child: content),
    );
  }
}

// MARK: - Figures

class ThisMonthFigures extends StatelessWidget {
  const ThisMonthFigures({
    super.key,
    required this.caption,
    required this.figures,
  });

  final String caption;
  final OverviewMonthFigures figures;

  static const _captionTopGap = 6.0;
  static const _negativePrefix = '-';
  static const _positivePrefix = '+';

  Color _netColor(SpendWiseColors colors) {
    if (figures.net.startsWith(_negativePrefix)) return colors.expense;
    if (figures.net.startsWith(_positivePrefix)) return colors.income;
    return colors.text;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spent = ThisMonthFigureRow(
      label: overviewThisMonthSpentLabel,
      value: figures.spent,
      color: colors.expense,
      isLast: false,
    );
    final income = ThisMonthFigureRow(
      label: overviewThisMonthIncomeLabel,
      value: figures.income,
      color: colors.income,
      isLast: false,
    );
    final net = ThisMonthFigureRow(
      label: overviewThisMonthNetLabel,
      value: figures.net,
      color: _netColor(colors),
      isLast: true,
    );
    final range = Padding(
      padding: const EdgeInsets.only(top: _captionTopGap),
      child: OverviewEmptyCopy(caption),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [spent, income, net, range],
    );
  }
}

// MARK: - Figure Row

class ThisMonthFigureRow extends StatelessWidget {
  const ThisMonthFigureRow({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    required this.isLast,
  });

  final String label;
  final String value;
  final Color color;
  final bool isLast;

  static const _verticalPadding = 10.0;
  static const _labelGap = 10.0;
  static const _labelWeight = FontWeight.w400;

  @override
  Widget build(BuildContext context) {
    final labelText = Text(
      label,
      style: TextStyle(
        fontSize: overviewBodyFontSize,
        fontWeight: _labelWeight,
        color: context.colors.subtext,
      ),
    );
    final valueText = Text(
      value,
      style: context.text.small.copyWith(color: color),
    );
    final divider = BorderSide(
      color: context.colors.edge,
      width: overviewRowDividerWidth,
    );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: _verticalPadding),
      decoration: isLast
          ? null
          : BoxDecoration(border: Border(bottom: divider)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          labelText,
          const SizedBox(width: _labelGap),
          valueText,
        ],
      ),
    );
  }
}
