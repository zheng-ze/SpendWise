import 'package:flutter/material.dart';

import 'package:spendwise/ui/format/amount_style.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

const _nameSize = 12.0;
const _captionSize = 10.0;
const _nameWeight = FontWeight.w600;
const _rowPadding = EdgeInsets.symmetric(vertical: 7);
const _rowGap = 8.0;
const _captionGap = 2.0;
const _swatchSize = 10.0;
const _swatchRadius = 3.0;
const _dividerWidth = 1.0;
const _chevron = Icons.chevron_right;
const _chevronSize = 14.0;
const _chevronPadding = EdgeInsets.only(left: 4);

class BreakdownRow extends StatelessWidget {
  const BreakdownRow({
    super.key,
    required this.swatchColor,
    required this.name,
    required this.caption,
    required this.amount,
    required this.amountKind,
    required this.divided,
    required this.onTap,
  });

  final Color swatchColor;
  final String name;
  final String caption;
  final String amount;
  final AmountKind amountKind;
  final bool divided;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final swatch = Container(
      width: _swatchSize,
      height: _swatchSize,
      decoration: BoxDecoration(
        color: swatchColor,
        borderRadius: BorderRadius.circular(_swatchRadius),
      ),
    );
    final captionStyle = TextStyle(
      fontSize: _captionSize,
      color: colors.subtext,
    );
    final label = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: const TextStyle(fontSize: _nameSize, fontWeight: _nameWeight),
        ),
        const SizedBox(height: _captionGap),
        Text(caption, style: captionStyle),
      ],
    );
    final amountText = Text(
      amount,
      textAlign: TextAlign.end,
      style: context.text.small.copyWith(
        color: AmountStyle.of(context, kind: amountKind).color,
      ),
    );
    final chevron = onTap == null
        ? null
        : Padding(
            padding: _chevronPadding,
            child: Icon(_chevron, size: _chevronSize, color: colors.subtext),
          );
    final content = Row(
      children: [
        swatch,
        const SizedBox(width: _rowGap),
        Expanded(child: label),
        const SizedBox(width: _rowGap),
        amountText,
        ?chevron,
      ],
    );
    final border = divided
        ? Border(
            bottom: BorderSide(color: colors.edge, width: _dividerWidth),
          )
        : null;
    final surface = Container(
      padding: _rowPadding,
      decoration: BoxDecoration(border: border),
      child: content,
    );
    return onTap == null ? surface : InkWell(onTap: onTap, child: surface);
  }
}
