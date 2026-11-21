import 'package:flutter/material.dart';

import 'package:spendwise/ui/theme/spendwise_text.dart';

// MARK: - EdgeDivider
class EdgeDivider extends StatelessWidget {
  const EdgeDivider({super.key, this.axis = Axis.horizontal});

  final Axis axis;

  static const _thickness = 1.0;

  @override
  Widget build(BuildContext context) {
    final line = ColoredBox(color: context.colors.edge);
    return switch (axis) {
      Axis.horizontal => SizedBox(height: _thickness, child: line),
      Axis.vertical => SizedBox(width: _thickness, child: line),
    };
  }
}
