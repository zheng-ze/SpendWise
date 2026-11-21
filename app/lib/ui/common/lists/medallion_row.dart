import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/lists/icon_medallion.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

// MARK: - MedallionRow
class MedallionRow extends StatelessWidget {
  const MedallionRow({
    super.key,
    this.icon,
    this.leading,
    this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
  }) : assert(icon != null || leading != null);

  final IconData? icon;

  final Widget? leading;

  final Color? iconColor;

  final String title;

  final String? subtitle;

  final Widget? trailing;

  static const _titleLineHeight = 1.25;

  static const _subtitleLineHeight = 1.3;

  static const _medallionLabelGap = 9.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final icon = this.icon;
    final medallion =
        leading ?? IconMedallion.row(icon: icon!, iconColor: iconColor);
    final subtitle = this.subtitle;
    final titleText = Text(
      title,
      style: context.text.body.copyWith(
        fontWeight: SpendWiseText.semibold,
        height: _titleLineHeight,
      ),
    );
    final labelLines = <Widget>[titleText];
    if (subtitle != null) {
      final subtitleText = Text(
        subtitle,
        style: context.text.caption.copyWith(
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
