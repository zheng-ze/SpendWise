import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/buttons/app_link_button.dart';
import 'package:spendwise/ui/common/feedback/load_error_view.dart';
import 'package:spendwise/ui/format/amount_style.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/overview/overview_constants.dart';
import 'package:spendwise/ui/theme/edge_border.dart';
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
    final divider = edgeSide(context.colors);
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
      child: AmountText(amount: amount, kind: kind),
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

  @override
  Widget build(BuildContext context) =>
      LoadErrorView.box(message: message, onRetry: onRetry);
}

// MARK: - Empty Copy

class OverviewEmptyCopy extends StatelessWidget {
  const OverviewEmptyCopy(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: context.text.caption.copyWith(color: context.colors.subtext),
  );
}

// MARK: - History Needed

const overviewHistoryNeededGap = 4.0;

class OverviewHistoryNeeded extends StatelessWidget {
  const OverviewHistoryNeeded({super.key, required this.body});

  final String body;

  @override
  Widget build(BuildContext context) {
    final title = Text(
      overviewHistoryNeededTitle,
      style: context.text.body.copyWith(fontWeight: SpendWiseText.semibold),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        title,
        const SizedBox(height: overviewHistoryNeededGap),
        OverviewEmptyCopy(body),
      ],
    );
  }
}

// MARK: - Link Action

class OverviewLinkAction extends StatelessWidget {
  const OverviewLinkAction({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final button = AppLinkButton(
      label: label,
      onPressed: onPressed,
      color: context.colors.action,
    );
    return Padding(
      padding: const EdgeInsets.only(top: overviewLinkTopPadding),
      child: button,
    );
  }
}
