import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

const _monthWindowSpanMonths = 1;
const _firstDayOfMonth = 1;

DateRange monthWindow(DateTime month) {
  final start = DateTime.utc(month.year, month.month);
  final end = shiftMonthThenClampDayUtc(
    start,
    _monthWindowSpanMonths,
    day: _firstDayOfMonth,
  );
  return DateRange(start, end);
}

DateRange yearWindow(DateTime year) {
  final start = DateTime.utc(year.year);
  final end = DateTime.utc(year.year + 1);
  return DateRange(start, end);
}

class AmountHeader extends StatelessWidget {
  const AmountHeader({
    super.key,
    required this.caption,
    required this.amount,
    required this.amountColor,
  });

  final String caption;
  final Decimal amount;
  final Color amountColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          caption,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          formatMoney(amount),
          style: context.text.headline.copyWith(color: amountColor),
        ),
      ],
    );
  }
}
