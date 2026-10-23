import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import 'package:spendwise/ui/format/amount_style.dart';
import 'package:spendwise/ui/format/date_format.dart';
import 'package:spendwise/ui/format/money_format.dart';

// MARK: - Constants
const double dayHeaderHeight = 56;

// MARK: - DayHeader
class DayHeader extends StatelessWidget {
  const DayHeader({super.key, required this.day, required this.net});

  final DateTime day;
  final Decimal net;

  static const _horizontalPadding = 16.0;
  static const _labelGap = 8.0;
  static const _amountGap = 8.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = formatDayHeader(day);
    final dayNumber = Text(
      label.dayNumber,
      style: theme.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    );
    final caption = Text(
      label.caption,
      softWrap: true,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
    final captionFlex = Expanded(child: caption);
    final dateLabel = Row(
      children: [
        dayNumber,
        const SizedBox(width: _labelGap),
        captionFlex,
      ],
    );
    final dateLabelFlex = Expanded(child: dateLabel);
    final netText = Text(
      formatMoney(net, symbol: false),
      style: theme.textTheme.titleSmall?.copyWith(
        color: AmountStyle.of(context, signedValue: net).color,
        fontWeight: FontWeight.w600,
      ),
    );
    final content = Row(
      children: [
        dateLabelFlex,
        const SizedBox(width: _amountGap),
        netText,
      ],
    );

    return Container(
      height: dayHeaderHeight,
      color: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
      child: content,
    );
  }
}

// MARK: - DayHeaderDelegate
class DayHeaderDelegate extends SliverPersistentHeaderDelegate {
  const DayHeaderDelegate({required this.day, required this.net});

  final DateTime day;
  final Decimal net;

  @override
  double get minExtent => dayHeaderHeight;

  @override
  double get maxExtent => dayHeaderHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return DayHeader(day: day, net: net);
  }

  @override
  bool shouldRebuild(covariant DayHeaderDelegate oldDelegate) {
    return oldDelegate.day != day || oldDelegate.net != net;
  }
}
