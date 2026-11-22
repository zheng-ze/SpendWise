import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/settings/display_preferences.dart';
import 'package:spendwise/ui/overview/overview_slots.dart';

void main() {
  test('overviewCardKinds lists the card kinds in declaration order', () {
    expect(overviewCardKinds, [
      OverviewWidgetKind.today,
      OverviewWidgetKind.thisMonth,
      OverviewWidgetKind.recentEntries,
      OverviewWidgetKind.comingUp,
    ]);
  });

  group('overviewWidgetsOrDefault', () {
    test('an empty list becomes the defaults', () {
      expect(
        overviewWidgetsOrDefault(const []),
        DisplayPreferences.defaults.overviewWidgets,
      );
    });

    test('a list with only cardless kinds becomes the defaults', () {
      expect(
        overviewWidgetsOrDefault(const [
          OverviewWidgetKind.topCategories,
          OverviewWidgetKind.insights,
        ]),
        DisplayPreferences.defaults.overviewWidgets,
      );
    });

    test('a list with a card kind is returned unchanged', () {
      const stored = [
        OverviewWidgetKind.topCategories,
        OverviewWidgetKind.comingUp,
      ];
      expect(overviewWidgetsOrDefault(stored), stored);
    });
  });
}
