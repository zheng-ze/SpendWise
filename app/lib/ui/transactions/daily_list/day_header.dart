import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import 'package:spendwise/ui/format/amount_style.dart';
import 'package:spendwise/ui/format/date_format.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

// MARK: - Constants
const double dayHeaderHeight = 56;
const double registerDayHeaderHeight = 46;

// MARK: - DayHeader
class DayHeader extends StatelessWidget {
  const DayHeader({super.key, required this.day, required this.net})
    : registerStyle = false;

  const DayHeader.register({super.key, required this.day, required this.net})
    : registerStyle = true;

  final DateTime day;
  final Decimal net;
  final bool registerStyle;

  static const _horizontalPadding = 16.0;
  static const _labelGap = 8.0;
  static const _amountGap = 8.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = formatDayHeader(day);
    if (registerStyle) {
      return _RegisterDayHeader(day: day, net: net);
    }
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

class _RegisterDayHeader extends StatelessWidget {
  const _RegisterDayHeader({required this.day, required this.net});

  final DateTime day;
  final Decimal net;

  static const _horizontalInset = 14.0;
  static const _topInset = 10.0;
  static const _bottomInset = 8.0;
  static const _dateFontSize = 12.0;
  static const _dateFontWeight = FontWeight.w600;
  static const _amountFontSize = 12.0;
  static const _amountFontWeight = FontWeight.w600;
  static const _borderWidth = 1.0;
  static const _cornerRadius = 14.0;
  static const _labelGap = 8.0;
  static const _pageInset = 14.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final netColor = AmountStyle.of(context, signedValue: net).color;
    final decoration = BoxDecoration(
      color: colors.surface,
      border: Border.all(color: colors.edge, width: _borderWidth),
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(_cornerRadius),
      ),
    );
    final date = Text(
      formatWeekdayDate(day),
      style: TextStyle(
        fontSize: _dateFontSize,
        fontWeight: _dateFontWeight,
        color: colors.text,
      ),
    );
    final amount = Text(
      formatMoney(net, symbol: false),
      style: TextStyle(
        fontSize: _amountFontSize,
        fontWeight: _amountFontWeight,
        color: netColor,
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _pageInset),
      child: Container(
        height: registerDayHeaderHeight,
        decoration: decoration,
        padding: const EdgeInsetsDirectional.fromSTEB(
          _horizontalInset,
          _topInset,
          _horizontalInset,
          _bottomInset,
        ),
        child: Row(
          children: [
            Expanded(child: date),
            const SizedBox(width: _labelGap),
            amount,
          ],
        ),
      ),
    );
  }
}

// MARK: - DayHeaderDelegate
class DayHeaderDelegate extends SliverPersistentHeaderDelegate {
  const DayHeaderDelegate({
    required this.day,
    required this.net,
    this.registerStyle = false,
  });

  final DateTime day;
  final Decimal net;
  final bool registerStyle;

  @override
  double get minExtent =>
      registerStyle ? registerDayHeaderHeight : dayHeaderHeight;

  @override
  double get maxExtent =>
      registerStyle ? registerDayHeaderHeight : dayHeaderHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return registerStyle
        ? DayHeader.register(day: day, net: net)
        : DayHeader(day: day, net: net);
  }

  @override
  bool shouldRebuild(covariant DayHeaderDelegate oldDelegate) {
    return oldDelegate.day != day ||
        oldDelegate.net != net ||
        oldDelegate.registerStyle != registerStyle;
  }
}
