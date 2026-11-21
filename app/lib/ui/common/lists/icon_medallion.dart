import 'package:flutter/material.dart';

import 'package:spendwise/ui/theme/spendwise_text.dart';

// MARK: - IconMedallion
class IconMedallion extends StatelessWidget {
  const IconMedallion.row({super.key, required this.icon, this.iconColor})
    : size = _rowSize,
      radius = _rowRadius,
      iconSize = _rowIconSize;

  const IconMedallion.empty({super.key, required this.icon, this.iconColor})
    : size = _emptySize,
      radius = _emptyRadius,
      iconSize = _emptyIconSize;

  final IconData icon;

  final Color? iconColor;

  final double size;

  final double radius;

  final double iconSize;

  static const _rowSize = 30.0;

  static const _rowRadius = 9.0;

  static const _rowIconSize = 17.0;

  static const _emptySize = 44.0;

  static const _emptyRadius = 13.0;

  static const _emptyIconSize = 22.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.tint,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(icon, size: iconSize, color: iconColor ?? colors.action),
    );
  }
}
