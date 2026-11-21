import 'package:flutter/material.dart';

import 'package:spendwise/ui/theme/edge_border.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

// MARK: - Tray
class Tray extends StatelessWidget {
  const Tray({
    super.key,
    this.title,
    this.trailing,
    this.selected = false,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    required this.child,
  });

  final String? title;

  final Widget? trailing;

  final bool selected;

  final CrossAxisAlignment crossAxisAlignment;

  final Widget child;

  static const cornerRadius = 14.0;

  static const contentPadding = 12.0;

  static Color fillColor(BuildContext context, {bool selected = false}) {
    final colors = context.colors;
    return selected ? colors.tint : colors.surface;
  }

  static BorderSide _edgeSide(BuildContext context, {bool selected = false}) {
    final colors = context.colors;
    if (!selected) return edgeSide(colors);
    return BorderSide(color: colors.action, width: edgeThickness);
  }

  static RoundedRectangleBorder shape(
    BuildContext context, {
    bool selected = false,
  }) {
    return RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(cornerRadius),
      side: _edgeSide(context, selected: selected),
    );
  }

  static BoxDecoration decoration(
    BuildContext context, {
    bool selected = false,
  }) {
    return BoxDecoration(
      color: fillColor(context, selected: selected),
      border: Border.fromBorderSide(_edgeSide(context, selected: selected)),
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
        crossAxisAlignment: crossAxisAlignment,
        children: content,
      ),
    );
  }
}

// MARK: - TrayHeader
class TrayHeader extends StatelessWidget {
  const TrayHeader({
    super.key,
    required this.title,
    this.trailing,
    this.stacked = false,
    this.bottomPadding = defaultBottomPadding,
  });

  final String title;

  final Widget? trailing;

  final bool stacked;

  final double bottomPadding;

  static const defaultBottomPadding = 6.0;

  @override
  Widget build(BuildContext context) {
    final titleText = Text(
      title,
      style: context.text.title.copyWith(fontWeight: SpendWiseText.semibold),
    );
    final trailing = this.trailing;
    Widget content = titleText;
    if (trailing != null && stacked) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [titleText, trailing],
      );
    } else if (trailing != null) {
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
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: content,
    );
  }
}
