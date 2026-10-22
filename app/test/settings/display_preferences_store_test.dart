import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spendwise/settings/display_preferences.dart';
import 'package:spendwise/settings/display_preferences_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('DisplayPreferencesStore.load', () {
    test('empty storage loads the defaults', () async {
      final prefs = await SharedPreferences.getInstance();

      expect(
        DisplayPreferencesStore(prefs).load(),
        DisplayPreferences.defaults,
      );
    });

    test('every field round-trips, including the savings pocket', () async {
      final prefs = await SharedPreferences.getInstance();
      final saved = DisplayPreferences(
        appearance: Appearance.dark,
        overviewWidgets: [
          OverviewWidgetKind.comingUp,
          OverviewWidgetKind.today,
        ],
        breakdownChart: BreakdownChart.categoryMap,
        breakdownLevel: BreakdownLevel.subcategories,
        chartColours: ChartColours.contrasting,
        insightCategoryChanges: false,
        insightUsualPace: false,
        dismissedInsights: {'2026-10:abc', '2026-09:def'},
        savingsPocketID: 'pocket-1',
      );

      await DisplayPreferencesStore(prefs).save(saved);

      expect(DisplayPreferencesStore(prefs).load(), saved);
    });

    test('an absent widget key loads the default set', () async {
      final prefs = await SharedPreferences.getInstance();

      final loaded = DisplayPreferencesStore(prefs).load();

      expect(loaded.overviewWidgets, [
        OverviewWidgetKind.today,
        OverviewWidgetKind.recentEntries,
        OverviewWidgetKind.comingUp,
      ]);
    });

    test('an empty widget value loads an empty set', () async {
      SharedPreferences.setMockInitialValues({
        'display.v1.overviewWidgets': '',
      });
      final prefs = await SharedPreferences.getInstance();

      expect(DisplayPreferencesStore(prefs).load().overviewWidgets, isEmpty);
    });

    test('unknown and duplicate widget codes are dropped', () async {
      SharedPreferences.setMockInitialValues({
        'display.v1.overviewWidgets': 'today,nope,today,comingUp,also-nope',
      });
      final prefs = await SharedPreferences.getInstance();

      expect(DisplayPreferencesStore(prefs).load().overviewWidgets, [
        OverviewWidgetKind.today,
        OverviewWidgetKind.comingUp,
      ]);
    });

    test('unknown enum codes fall back to their defaults', () async {
      SharedPreferences.setMockInitialValues({
        'display.v1.appearance': 'neon',
        'display.v1.breakdownChart': 'pie',
        'display.v1.breakdownLevel': 'streets',
        'display.v1.chartColours': 'rainbow',
      });
      final prefs = await SharedPreferences.getInstance();

      final loaded = DisplayPreferencesStore(prefs).load();

      expect(loaded.appearance, Appearance.system);
      expect(loaded.breakdownChart, BreakdownChart.donut);
      expect(loaded.breakdownLevel, BreakdownLevel.categories);
      expect(loaded.chartColours, ChartColours.categoryColours);
    });
  });
}
