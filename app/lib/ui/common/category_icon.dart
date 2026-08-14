import 'package:flutter/material.dart';

import 'package:spendwise/ui/symbol_map.dart';

const double _glyphFraction = 0.44;
const double _ringThickness = 2;
const double _unselectedFillOpacity = 0.15;

class CategoryIcon extends StatelessWidget {
  const CategoryIcon({
    super.key,
    required this.symbolName,
    required this.color,
    this.size = 32,
    this.selected = false,
  });

  final String symbolName;
  final Color color;
  final double size;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected
            ? color
            : color.withValues(alpha: _unselectedFillOpacity),
        border: selected
            ? Border.all(color: color, width: _ringThickness)
            : null,
      ),
      alignment: Alignment.center,
      child: Icon(
        symbolIcon(symbolName),
        size: size * _glyphFraction,
        color: selected ? Colors.white : color,
      ),
    );
  }
}
