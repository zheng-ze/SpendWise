import 'package:flutter/material.dart';

import 'package:spendwise/ui/theme/spendwise_colors.dart';

// MARK: - Constants
const edgeThickness = 1.0;

// MARK: - Helpers
BorderSide edgeSide(SpendWiseColors colors) {
  return BorderSide(color: colors.edge, width: edgeThickness);
}

Border bottomEdgeBorder(SpendWiseColors colors) {
  return Border(bottom: edgeSide(colors));
}

Border topEdgeBorder(SpendWiseColors colors) {
  return Border(top: edgeSide(colors));
}

Border fullEdgeBorder(SpendWiseColors colors) {
  return Border.fromBorderSide(edgeSide(colors));
}
