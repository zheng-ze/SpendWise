import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/lists/category_icon.dart';
import 'package:spendwise/ui/format/amount_style.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/symbol_map.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';
import 'package:spendwise/ui/transactions/daily_list/transaction_row.dart';

// MARK: - TransactionCell
class TransactionCell extends StatelessWidget {
  const TransactionCell({super.key, required this.row, this.onTap})
    : isRegisterStyle = false,
      isLastInDay = false;

  const TransactionCell.register({
    super.key,
    required this.row,
    this.onTap,
    required this.isLastInDay,
  }) : isRegisterStyle = true;

  final TransactionRow row;
  final VoidCallback? onTap;
  final bool isRegisterStyle;
  final bool isLastInDay;

  static const _cellHorizontalPadding = 16.0;
  static const _cellVerticalPadding = 10.0;
  static const _contentGap = 12.0;

  @override
  Widget build(BuildContext context) {
    if (isRegisterStyle) {
      return _RegisterTransactionCell(
        row: row,
        onTap: onTap,
        isLastInDay: isLastInDay,
      );
    }

    final theme = Theme.of(context);
    final captionStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: _cellHorizontalPadding,
          vertical: _cellVerticalPadding,
        ),
        child: Row(
          children: [
            CategoryIcon(symbolName: row.symbolName, color: row.color),
            const SizedBox(width: _contentGap),
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
            const SizedBox(width: _contentGap),
            Text(
              formatSignedMoney(
                row.amount,
                kind: row.amountKind,
                symbol: false,
              ),
              style: theme.textTheme.titleSmall?.copyWith(
                color: AmountStyle.of(context, kind: row.amountKind).color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RegisterTransactionCell extends StatelessWidget {
  const _RegisterTransactionCell({
    required this.row,
    required this.isLastInDay,
    this.onTap,
  });

  final TransactionRow row;
  final bool isLastInDay;
  final VoidCallback? onTap;

  static const _cellHorizontalInset = 12.0;
  static const _cellVerticalInset = 8.0;
  static const _iconSize = 30.0;
  static const _iconRadius = 9.0;
  static const _iconGlyphSize = 17.0;
  static const _contentGap = 9.0;
  static const _amountGap = 8.0;
  static const _titleSize = 12.0;
  static const _titleWeight = FontWeight.w600;
  static const _subtitleSize = 10.0;
  static const _subtitleLineHeight = 1.3;
  static const _amountSize = 12.0;
  static const _amountWeight = FontWeight.w600;
  static const _rowBorderWidth = 1.0;
  static const _rowCornerRadius = 14.0;
  static const _rowMargin = 14.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final subtitleStyle = TextStyle(
      fontSize: _subtitleSize,
      height: _subtitleLineHeight,
      color: colors.subtext,
    );
    final primaryText = row.note.isEmpty ? row.title : row.note;
    final secondaryText = row.note.isEmpty
        ? row.accountLine
        : '${row.title} / ${row.accountLine}';
    final border = BorderSide(color: colors.edge, width: _rowBorderWidth);
    final decoration = BoxDecoration(
      border: Border(left: border, right: border, bottom: border),
      borderRadius: isLastInDay
          ? const BorderRadius.vertical(
              bottom: Radius.circular(_rowCornerRadius),
            )
          : null,
    );
    final icon = Container(
      width: _iconSize,
      height: _iconSize,
      decoration: BoxDecoration(
        color: colors.tint,
        borderRadius: BorderRadius.circular(_iconRadius),
      ),
      alignment: Alignment.center,
      child: Icon(
        symbolIcon(row.symbolName),
        size: _iconGlyphSize,
        color: row.color,
      ),
    );
    final description = Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            primaryText,
            style: TextStyle(
              fontSize: _titleSize,
              fontWeight: _titleWeight,
              color: colors.text,
            ),
          ),
          Text(secondaryText, style: subtitleStyle),
        ],
      ),
    );
    final amount = Text(
      formatSignedMoney(row.amount, kind: row.amountKind, symbol: false),
      style: context.text.row.copyWith(
        fontSize: _amountSize,
        fontWeight: _amountWeight,
        color: AmountStyle.of(context, kind: row.amountKind).color,
      ),
    );
    final content = Ink(
      decoration: decoration,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: _cellHorizontalInset,
          vertical: _cellVerticalInset,
        ),
        child: Row(
          children: [
            icon,
            const SizedBox(width: _contentGap),
            description,
            const SizedBox(width: _amountGap),
            amount,
          ],
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: _rowMargin),
      child: Material(
        color: colors.surface,
        borderRadius: decoration.borderRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          hoverColor: colors.interactionSurface,
          highlightColor: colors.interactionSurface,
          child: content,
        ),
      ),
    );
  }
}
