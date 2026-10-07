import 'package:flutter/material.dart';

import 'package:spendwise/ui/theme/spendwise_text.dart';

class MedallionRow extends StatelessWidget {
  const MedallionRow({
    super.key,
    required this.icon,
    this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final IconData icon;

  final Color? iconColor;

  final String title;

  final String? subtitle;

  final Widget? trailing;

  static const _medallionSize = 30.0;

  static const _medallionRadius = 9.0;

  static const _medallionIconSize = 17.0;

  static const _titleFontSize = 12.0;

  static const _titleLineHeight = 1.25;

  static const _subtitleFontSize = 10.0;

  static const _subtitleLineHeight = 1.3;

  static const _medallionLabelGap = 9.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final medallion = Container(
      width: _medallionSize,
      height: _medallionSize,
      decoration: BoxDecoration(
        color: colors.tint,
        borderRadius: BorderRadius.circular(_medallionRadius),
      ),
      child: Icon(
        icon,
        size: _medallionIconSize,
        color: iconColor ?? colors.action,
      ),
    );
    final subtitle = this.subtitle;
    final titleText = Text(
      title,
      style: const TextStyle(
        fontSize: _titleFontSize,
        fontWeight: FontWeight.w600,
        height: _titleLineHeight,
      ),
    );
    final labelLines = <Widget>[titleText];
    if (subtitle != null) {
      final subtitleText = Text(
        subtitle,
        style: TextStyle(
          fontSize: _subtitleFontSize,
          color: colors.subtext,
          height: _subtitleLineHeight,
        ),
      );
      labelLines.add(subtitleText);
    }
    final labels = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: labelLines,
    );
    final trailing = this.trailing;
    final row = <Widget>[
      medallion,
      const SizedBox(width: _medallionLabelGap),
      Expanded(child: labels),
    ];
    if (trailing != null) row.add(trailing);

    return Row(children: row);
  }
}
