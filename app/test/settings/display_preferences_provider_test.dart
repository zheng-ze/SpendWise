import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spendwise/main.dart';
import 'package:spendwise/settings/display_preferences.dart';
import 'package:spendwise/settings/display_preferences_providers.dart';
import 'package:spendwise/settings/display_preferences_store.dart';

final _darkCustom = DisplayPreferences(
  appearance: Appearance.dark,
  overviewWidgets: [
    OverviewWidgetKind.comingUp,
    OverviewWidgetKind.today,
    OverviewWidgetKind.recentEntries,
  ],
);

ProviderContainer _containerWith(DisplayPreferences initial) {
  final container = ProviderContainer(
    overrides: [initialDisplayPreferencesProvider.overrideWithValue(initial)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('replacing preferences updates state and persists', () async {
    final container = _containerWith(DisplayPreferences.defaults);

    await container
        .read(displayPreferencesProvider.notifier)
        .replace(_darkCustom);

    expect(container.read(displayPreferencesProvider), _darkCustom);
    final prefs = await SharedPreferences.getInstance();
    expect(DisplayPreferencesStore(prefs).load(), _darkCustom);
  });

  test('a restart keeps Dark and a custom widget order', () async {
    final first = _containerWith(DisplayPreferences.defaults);
    await first.read(displayPreferencesProvider.notifier).replace(_darkCustom);
    first.dispose();

    final prefs = await SharedPreferences.getInstance();
    final restarted = _containerWith(DisplayPreferencesStore(prefs).load());

    expect(
      restarted.read(displayPreferencesProvider).appearance,
      Appearance.dark,
    );
    expect(restarted.read(displayPreferencesProvider).overviewWidgets, [
      OverviewWidgetKind.comingUp,
      OverviewWidgetKind.today,
      OverviewWidgetKind.recentEntries,
    ]);
  });

  test('a read that throws still boots with defaults', () async {
    final loaded = await loadInitialDisplayPreferences(
      () async => throw StateError('storage unavailable'),
    );

    expect(loaded, DisplayPreferences.defaults);
  });
}
