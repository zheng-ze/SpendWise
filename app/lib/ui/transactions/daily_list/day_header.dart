import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import 'package:spendwise/ui/format/amount_color.dart';
import 'package:spendwise/ui/format/date_format.dart';
import 'package:spendwise/ui/format/money_format.dart';

const double dayHeaderHeight = 56;

class DayHeader extends StatelessWidget {
  const DayHeader({super.key, required this.day, required this.net});

  final DateTime day;
  final Decimal net;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = formatDayHeader(day);
    final colors = AmountColors.of(theme);

    return Container(
      height: dayHeaderHeight,
      color: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(
            label.dayNumber,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label.caption,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          Text(
            formatCurrency(net),
            style: theme.textTheme.titleSmall?.copyWith(
              color: colors.netAmountColor(net),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

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
