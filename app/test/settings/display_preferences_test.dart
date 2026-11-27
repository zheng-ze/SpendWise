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
    });

    test('constructed collections reject mutation', () {
      final preferences = DisplayPreferences(
        overviewWidgets: [OverviewWidgetKind.today],
      );

      expect(
        () => preferences.overviewWidgets.add(OverviewWidgetKind.comingUp),
        throwsUnsupportedError,
      );
    });

    test('loaded collections reject mutation', () async {
      SharedPreferences.setMockInitialValues({
        'display.v1.overviewWidgets': 'today,comingUp',
      });
      final loaded = DisplayPreferencesStore(
        await SharedPreferences.getInstance(),
      ).load();

      expect(
        () => loaded.overviewWidgets.add(OverviewWidgetKind.recentEntries),
        throwsUnsupportedError,
      );
    });

    test('copied collections reject mutation', () {
      final copied = DisplayPreferences.defaults.copyWith(
        overviewWidgets: [OverviewWidgetKind.insights],
      );

      expect(
        () => copied.overviewWidgets.add(OverviewWidgetKind.today),
        throwsUnsupportedError,
      );
    });
  });
}
