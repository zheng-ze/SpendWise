import 'package:flutter/material.dart';

import 'package:spendwise/ui/theme/spendwise_text.dart';

// MARK: - Tray
class Tray extends StatelessWidget {
  const Tray({
    super.key,
    this.title,
    this.trailing,
    this.selected = false,
    required this.child,
  });

  final String? title;

  final Widget? trailing;

  final bool selected;

  final Widget child;

  static const cornerRadius = 14.0;

  static const contentPadding = 12.0;

  static const semiBoldWeight = FontWeight.w600;

  static const borderWidth = 1.0;

  static BoxDecoration decoration(
    BuildContext context, {
    bool selected = false,
  }) {
    final colors = context.colors;
    final borderColor = selected ? colors.action : colors.edge;
    return BoxDecoration(
      color: selected ? colors.tint : colors.surface,
      border: Border.all(color: borderColor, width: borderWidth),
      borderRadius: BorderRadius.circular(cornerRadius),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = this.title;
    final header = title == null
        ? null
        : TrayHeader(title: title, trailing: trailing);
    final content = <Widget>[];
    if (header != null) content.add(header);
    content.add(child);

    return Container(
      decoration: decoration(context, selected: selected),
      padding: const EdgeInsets.all(contentPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: content,
      ),
    );
  }
}

// MARK: - TrayHeader
class TrayHeader extends StatelessWidget {
  const TrayHeader({super.key, required this.title, this.trailing});

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
        fontWeight: Tray.semiBoldWeight,
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
