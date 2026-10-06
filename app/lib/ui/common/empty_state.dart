import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/app_buttons.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;

  final String title;

  final String? body;

  final String? actionLabel;

  final VoidCallback? onAction;

  static const _padding = EdgeInsets.symmetric(horizontal: 12, vertical: 22);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final medallion = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: colors.tint,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(icon, size: 22, color: colors.action),
    );
    final body = this.body;
    final actionLabel = this.actionLabel;
    final onAction = this.onAction;
    final action = actionLabel != null && onAction != null
        ? _EmptyAction(label: actionLabel, onPressed: onAction)
        : null;

    Text? bodyText;
    if (body != null) {
      bodyText = Text(
        body,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, color: colors.subtext, height: 1.45),
      );
    }
    final titleText = Text(
      title,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    );
    final content = <Widget>[medallion, const SizedBox(height: 10), titleText];
    if (bodyText != null) {
      content.add(
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 230),
          child: bodyText,
        ),
      );
    }
    if (action != null) content.add(action);
    final column = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: content,
    );
    if (Theme.of(context).brightness != Brightness.light) {
      return Padding(padding: _padding, child: column);
    }

    final decoration = BoxDecoration(
      color: colors.surface,
      border: Border.all(color: colors.edge),
      borderRadius: BorderRadius.circular(14),
    );
    return Container(decoration: decoration, padding: _padding, child: column);
  }
}

class _EmptyAction extends StatelessWidget {
  const _EmptyAction({required this.label, required this.onPressed});

  final String label;

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: PrimaryButton(label: label, onPressed: onPressed),
    );
  }
}
