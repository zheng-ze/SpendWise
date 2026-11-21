import 'package:flutter/material.dart';

import 'package:spendwise/ui/theme/edge_border.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

// MARK: - EdgeDivider
class EdgeDivider extends StatelessWidget {
  const EdgeDivider({super.key, this.axis = Axis.horizontal});

  final Axis axis;

  @override
  Widget build(BuildContext context) {
    final line = ColoredBox(color: context.colors.edge);
    return switch (axis) {
      Axis.horizontal => SizedBox(height: edgeThickness, child: line),
      Axis.vertical => SizedBox(width: edgeThickness, child: line),
    };
  }
}
