import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/buttons/app_buttons.dart';
import 'package:spendwise/ui/common/lists/icon_medallion.dart';
import 'package:spendwise/ui/common/sheets/tray.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

// MARK: - Constants

const _semiBoldWeight = FontWeight.w600;

// MARK: - EmptyState
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

  static const _titleGap = 10.0;

  static const _titleFontSize = 14.0;

  static const _bodyFontSize = 12.0;

  static const _bodyLineHeight = 1.45;

  static const _bodyMaxWidth = 230.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final medallion = IconMedallion.empty(icon: icon);
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
        style: TextStyle(
          fontSize: _bodyFontSize,
          color: colors.subtext,
          height: _bodyLineHeight,
        ),
      );
    }
    final titleText = Text(
      title,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: _titleFontSize,
        fontWeight: _semiBoldWeight,
      ),
    );
    final content = <Widget>[
      medallion,
      const SizedBox(height: _titleGap),
      titleText,
    ];
    if (bodyText != null) {
      content.add(
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _bodyMaxWidth),
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

    return Container(
      decoration: Tray.decoration(context),
      padding: _padding,
      child: column,
    );
  }
}

// MARK: - EmptyAction
class _EmptyAction extends StatelessWidget {
  const _EmptyAction({required this.label, required this.onPressed});

  static const _actionTopPadding = 10.0;

  final String label;

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: _actionTopPadding),
      child: PrimaryButton(label: label, onPressed: onPressed),
    );
  }
}
