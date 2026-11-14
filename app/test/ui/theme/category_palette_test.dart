import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/theme/category_palette.dart';
import 'package:spendwise/ui/theme/spendwise_colors.dart';

void main() {
  group('CategoryPalette.savedColor', () {
    test('maps a saved Harbour hex to its light counterpart', () {
      expect(
        CategoryPalette.savedColor('#34C759', SpendWiseColors.light),
        SpendWiseColors.light.groceries,
      );
    });

    test('maps a saved Harbour hex to its dark counterpart', () {
      expect(
        CategoryPalette.savedColor('#34C759', SpendWiseColors.dark),
        SpendWiseColors.dark.groceries,
      );
    });
  });
}
