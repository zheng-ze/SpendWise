import 'package:flutter/material.dart';
import 'package:spendwise/settings/display_preferences.dart';
import 'package:spendwise/ui/theme/category_palette.dart';

import 'package:spendwise/ui/theme/spendwise_text.dart';

class BudgetCard extends StatelessWidget {
  const BudgetCard({
    super.key,
    required this.name,
    required this.amounts,
    required this.status,
    required this.progress,
    required this.overLimit,
    required this.onTap,
    required this.savedHex,
    required this.rank,
    required this.chartColours,
  });

  final String? savedHex;
  final int rank;
  final ChartColours chartColours;
  final String name;
  final String amounts;
  final String status;
  final double progress;
  final bool overLimit;
  final VoidCallback onTap;

  static const _padding = EdgeInsets.symmetric(vertical: 7);
  static const _gap = 5.0;
  static const _headerGap = 8.0;
  static const _fontSize = 12.0;
  static const _labelWeight = FontWeight.w600;
  static const _barHeight = 7.0;
  static const _barRadius = 4.0;
  static const _fullWidth = double.infinity;
  static const _minimum = 0.0;
  static const _maximum = 1.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final label = Text(
      name,
      style: const TextStyle(fontSize: _fontSize, fontWeight: _labelWeight),
    );
    final amount = Text(amounts, style: context.text.small);
    final labels = Wrap(
      alignment: WrapAlignment.spaceBetween,
      spacing: _headerGap,
      children: [label, amount],
    );
    final header = SizedBox(width: _fullWidth, child: labels);
    final bar = LinearProgressIndicator(
      value: progress.clamp(_minimum, _maximum),
      minHeight: _barHeight,
      borderRadius: BorderRadius.circular(_barRadius),
      color: overLimit
          ? colors.expense
          : CategoryPalette.resolve(
              savedHex: savedHex,
              rank: rank,
              mode: chartColours,
              colors: colors,
            ),
      backgroundColor: colors.tint,
    );
    final caption = Text(
      status,
      style: Theme.of(context).textTheme.bodySmall
          ?.copyWith(color: overLimit ? colors.expense : colors.subtext),
    );
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        const SizedBox(height: _gap),
        bar,
        const SizedBox(height: _gap),
        caption,
      ],
    );
    return InkWell(
      onTap: onTap,
      child: Padding(padding: _padding, child: content),
    );
  }
}
