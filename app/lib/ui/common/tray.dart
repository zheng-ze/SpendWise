import 'package:flutter/material.dart';

import 'package:spendwise/ui/theme/spendwise_text.dart';

class Tray extends StatelessWidget {
  const Tray({super.key, this.title, this.trailing, required this.child});

  final String? title;

  final Widget? trailing;

  final Widget child;

  static const _cornerRadius = 14.0;

  static const _contentPadding = 12.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final title = this.title;
    final header = title == null
        ? null
        : _TrayHeader(title: title, trailing: trailing);
    final content = <Widget>[];
    if (header != null) content.add(header);
    content.add(child);

    final decoration = BoxDecoration(
      color: colors.surface,
      border: Border.all(color: colors.edge),
      borderRadius: BorderRadius.circular(_cornerRadius),
    );
    return Container(
      decoration: decoration,
      padding: const EdgeInsets.all(_contentPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: content,
      ),
    );
  }
}

class _TrayHeader extends StatelessWidget {
  const _TrayHeader({required this.title, required this.trailing});

  final String title;

  final Widget? trailing;

  static const _titleFontSize = 14.0;

  static const _titleLineHeight = 1.25;

  static const _headerBottomPadding = 6.0;

  @override
  Widget build(BuildContext context) {
    final titleText = Text(
      title,
      style: const TextStyle(
        fontSize: _titleFontSize,
        fontWeight: FontWeight.w600,
        height: _titleLineHeight,
      ),
    );
    final trailing = this.trailing;
    Widget content = titleText;
    if (trailing != null) {
      content = Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(child: titleText),
          trailing,
        ],
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: _headerBottomPadding),
      child: content,
    );
  }
}
