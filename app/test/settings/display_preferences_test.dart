import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spendwise/settings/display_preferences.dart';
import 'package:spendwise/settings/display_preferences_store.dart';

void main() {
  group('DisplayPreferences immutability', () {
    test('the default collections reject mutation', () {
      expect(
        () => DisplayPreferences.defaults.overviewWidgets.add(
          OverviewWidgetKind.today,
        ),
        throwsUnsupportedError,
      );
      expect(
        () => DisplayPreferences.defaults.dismissedInsights.add('2026-10:x'),
        throwsUnsupportedError,
      );
    });

    test('constructed collections reject mutation', () {
      final preferences = DisplayPreferences(
        overviewWidgets: [OverviewWidgetKind.today],
        dismissedInsights: {'2026-10:x'},
      );

      expect(
        () => preferences.overviewWidgets.add(OverviewWidgetKind.comingUp),
        throwsUnsupportedError,
      );
      expect(
        () => preferences.dismissedInsights.add('2026-11:y'),
        throwsUnsupportedError,
      );
    });

    test('loaded collections reject mutation', () async {
      SharedPreferences.setMockInitialValues({
        'display.v1.overviewWidgets': 'today,comingUp',
        'display.v1.insights.dismissed': ['2026-10:x'],
      });
      final loaded = DisplayPreferencesStore(
        await SharedPreferences.getInstance(),
      ).load();

      expect(
        () => loaded.overviewWidgets.add(OverviewWidgetKind.recentEntries),
        throwsUnsupportedError,
      );
      expect(
        () => loaded.dismissedInsights.add('2026-11:y'),
        throwsUnsupportedError,
      );
    });

    test('copied collections reject mutation', () {
      final copied = DisplayPreferences.defaults.copyWith(
        overviewWidgets: [OverviewWidgetKind.insights],
        dismissedInsights: {'2026-10:x'},
      );

      expect(
        () => copied.overviewWidgets.add(OverviewWidgetKind.today),
        throwsUnsupportedError,
      );
      expect(
        () => copied.dismissedInsights.add('2026-11:y'),
        throwsUnsupportedError,
      );
    });
  });
}
