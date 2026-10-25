import 'package:flutter/material.dart';

import 'package:spendwise/ui/format/amount_style.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/symbol_map.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';
import 'package:spendwise/ui/transactions/daily_list/transaction_row.dart';

// MARK: - TransactionCell
class TransactionCell extends StatelessWidget {
  const TransactionCell({
    super.key,
    required this.row,
    this.onTap,
    this.isLastInDay = false,
  });

  final TransactionRow row;
  final VoidCallback? onTap;
  final bool isLastInDay;

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
      color: colors.surface,
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
    final content = Container(
      margin: const EdgeInsetsDirectional.symmetric(horizontal: _rowMargin),
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

    return InkWell(onTap: onTap, child: content);
  }
}
