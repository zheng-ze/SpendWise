import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/app_buttons.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

@immutable
class NoticeCardAction {
  const NoticeCardAction({required this.label, required this.onPressed});

  final String label;

  final VoidCallback onPressed;
}

class NoticeCard extends StatelessWidget {
  const NoticeCard({
    super.key,
    required this.title,
    this.body,
    this.primaryAction,
    this.secondaryAction,
  });

  final String title;

  final String? body;

  final NoticeCardAction? primaryAction;

  final NoticeCardAction? secondaryAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final body = this.body;
    final primaryAction = this.primaryAction;
    final secondaryAction = this.secondaryAction;
    final actions = primaryAction == null && secondaryAction == null
        ? null
        : _NoticeActions(
            primaryAction: primaryAction,
            secondaryAction: secondaryAction,
          );

    final bodyText = body == null
        ? null
        : Text(
            body,
            style: TextStyle(fontSize: 12, color: colors.notice, height: 1.45),
          );
    final titleText = Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: colors.notice,
        height: 1.45,
      ),
    );
    final content = <Widget>[titleText];
    if (bodyText != null) content.add(bodyText);
    if (actions != null) content.add(actions);

    final decoration = BoxDecoration(
      color: colors.noticeBg,
      border: Border.all(color: colors.notice),
      borderRadius: BorderRadius.circular(10),
    );
    return Container(
      decoration: decoration,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: content,
      ),
    );
  }
}

class _NoticeActions extends StatelessWidget {
  const _NoticeActions({
    required this.primaryAction,
    required this.secondaryAction,
  });

  final NoticeCardAction? primaryAction;

  final NoticeCardAction? secondaryAction;

  @override
  Widget build(BuildContext context) {
    final primaryAction = this.primaryAction;
    final secondaryAction = this.secondaryAction;
    final buttons = <Widget>[];
    if (primaryAction != null) {
      final primary = PrimaryButton(
        label: primaryAction.label,
        onPressed: primaryAction.onPressed,
      );
      buttons.add(primary);
    }
    if (secondaryAction != null) {
      final secondary = SecondaryButton(
        label: secondaryAction.label,
        onPressed: secondaryAction.onPressed,
      );
      buttons.add(secondary);
    }
    final bar = OverflowBar(
      alignment: MainAxisAlignment.start,
      spacing: 14,
      overflowSpacing: 8,
      children: buttons,
    );
    return Padding(padding: const EdgeInsets.only(top: 6), child: bar);
  }
}
