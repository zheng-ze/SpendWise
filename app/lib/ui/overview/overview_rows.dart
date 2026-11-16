import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/buttons/app_buttons.dart';
import 'package:spendwise/ui/format/amount_style.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/overview/overview_constants.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

// MARK: - Row Frame

class OverviewRowFrame extends StatelessWidget {
  const OverviewRowFrame({
    super.key,
    required this.isLast,
    required this.child,
  });

  final bool isLast;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final divider = BorderSide(
      color: context.colors.edge,
      width: overviewRowDividerWidth,
    );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: overviewRowVerticalPadding),
      decoration: isLast
          ? null
          : BoxDecoration(border: Border(bottom: divider)),
      child: child,
    );
  }
}

// MARK: - Amount

class OverviewAmountText extends StatelessWidget {
  const OverviewAmountText({
    super.key,
    required this.amount,
    required this.kind,
  });

  final Decimal amount;
  final AmountKind kind;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: overviewRowTrailingGap),
      child: Text(
        formatSignedMoney(amount, kind: kind, symbol: false),
        style: context.text.small.copyWith(
          color: AmountStyle.of(context, kind: kind).color,
        ),
      ),
    );
  }
}

// MARK: - Load Error

class OverviewLoadError extends StatelessWidget {
  const OverviewLoadError({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  static const _messageGap = 10.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message,
          style: TextStyle(
            fontSize: overviewBodyFontSize,
            fontWeight: overviewSemiBold,
            color: context.colors.error,
          ),
        ),
        const SizedBox(height: _messageGap),
        PrimaryButton(label: overviewRetryLabel, onPressed: onRetry),
      ],
    );
  }
}

// MARK: - Empty Copy

class OverviewEmptyCopy extends StatelessWidget {
  const OverviewEmptyCopy(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      fontSize: overviewSmallFontSize,
      color: context.colors.subtext,
    ),
  );
}
