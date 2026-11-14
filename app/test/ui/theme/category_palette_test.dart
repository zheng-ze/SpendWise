import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/theme/category_palette.dart';
import 'package:spendwise/ui/theme/spendwise_colors.dart';

void main() {
  group('CategoryPalette.savedColor', () {
    test('maps each saved hex to the matching token of the active theme', () {
      for (final colors in [SpendWiseColors.light, SpendWiseColors.dark]) {
        expect(CategoryPalette.savedColor('#34C759', colors), colors.groceries);
        expect(CategoryPalette.savedColor('#AF52DE', colors), colors.fitness);
        expect(CategoryPalette.savedColor('#8E8E93', colors), colors.housing);
      }
    });

    test('keeps a neutral grey of its own when no colour is saved', () {
      for (final colors in [SpendWiseColors.light, SpendWiseColors.dark]) {
        final neutral = CategoryPalette.savedColor(null, colors);
        expect(neutral, isNot(colors.housing));
        expect(CategoryPalette.savedColor('not a colour', colors), neutral);
        expect(CategoryPalette.savedColor('#12345', colors), neutral);
      }
    });
  });
}
