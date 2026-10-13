import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

// MARK: - AmountHeader
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
