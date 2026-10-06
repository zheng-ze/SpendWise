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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final medallion = Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: colors.tint,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(icon, size: 17, color: iconColor ?? colors.action),
    );
    final subtitle = this.subtitle;
    final labelLines = <Widget>[
      Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          height: 1.25,
        ),
      ),
    ];
    if (subtitle != null) {
      labelLines.add(
        Text(
          subtitle,
          style: TextStyle(fontSize: 10, color: colors.subtext, height: 1.3),
        ),
      );
    }
    final labels = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: labelLines,
    );
    final trailing = this.trailing;
    final row = <Widget>[
      medallion,
      const SizedBox(width: 9),
      Expanded(child: labels),
    ];
    if (trailing != null) row.add(trailing);

    return Row(children: row);
  }
}
