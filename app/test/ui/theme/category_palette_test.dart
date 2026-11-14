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

    test('maps the saved fitness and housing hexes to their light tokens', () {
      expect(
        CategoryPalette.savedColor('#AF52DE', SpendWiseColors.light),
        SpendWiseColors.light.fitness,
      );
      expect(
        CategoryPalette.savedColor('#8E8E93', SpendWiseColors.light),
        SpendWiseColors.light.housing,
      );
    });

    test('maps the saved fitness and housing hexes to their dark tokens', () {
      expect(
        CategoryPalette.savedColor('#AF52DE', SpendWiseColors.dark),
        SpendWiseColors.dark.fitness,
      );
      expect(
        CategoryPalette.savedColor('#8E8E93', SpendWiseColors.dark),
        SpendWiseColors.dark.housing,
      );
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
