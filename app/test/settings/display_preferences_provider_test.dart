import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spendwise/boot/app_boot.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/main.dart';
import 'package:spendwise/persistence/ledger_store.dart';
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

Future<void> _pumpApp(
  WidgetTester tester, {
  required DisplayPreferences initial,
  required Brightness platform,
}) async {
  tester.platformDispatcher.platformBrightnessTestValue = platform;
  addTearDown(
    () => tester.platformDispatcher.clearPlatformBrightnessTestValue(),
  );
  final container = ProviderContainer(
    overrides: [
      initialDisplayPreferencesProvider.overrideWithValue(initial),
      appBootProvider.overrideWith(
        (ref) => AppBoot(
          createStore: () => Completer<LedgerStore>().future,
          seedChanges: () => [],
        )..start(),
      ),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const SpendWiseApp(),
    ),
  );
  await tester.pump();
}

Brightness _appBrightness(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(Scaffold))).brightness;

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

  testWidgets('a stored Dark overrides a light platform', (tester) async {
    await _pumpApp(
      tester,
      initial: DisplayPreferences(appearance: Appearance.dark),
      platform: Brightness.light,
    );

    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
    expect(_appBrightness(tester), Brightness.dark);
  });

  testWidgets('System follows the platform', (tester) async {
    await _pumpApp(
      tester,
      initial: DisplayPreferences.defaults,
      platform: Brightness.dark,
    );

    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.system,
    );
    expect(_appBrightness(tester), Brightness.dark);
  });

  testWidgets('a stored Light overrides a dark platform', (tester) async {
    await _pumpApp(
      tester,
      initial: DisplayPreferences(appearance: Appearance.light),
      platform: Brightness.dark,
    );

    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.light,
    );
    expect(_appBrightness(tester), Brightness.light);
  });

  test('a read that throws still boots with defaults', () async {
    final loaded = await loadInitialDisplayPreferences(
      () async => throw StateError('storage unavailable'),
    );

    expect(loaded, DisplayPreferences.defaults);
  });
}
