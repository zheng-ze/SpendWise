import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/category_icon.dart';
import 'package:spendwise/ui/format/amount_color.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/transactions/transaction_row.dart';

class TransactionCell extends StatelessWidget {
  const TransactionCell({super.key, required this.row, this.onTap});

  final TransactionRow row;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final captionStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final colors = AmountColors.of(theme);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            CategoryIcon(symbolName: row.symbolName, color: row.color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(row.title, style: theme.textTheme.bodyMedium),
                  if (row.note.isNotEmpty) Text(row.note, style: captionStyle),
                  Text(row.accountLine, style: captionStyle),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              formatSignedAmount(row.amount, row.amountKind),
              style: theme.textTheme.titleSmall?.copyWith(
                color: colors.kindColor(row.amountKind),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
