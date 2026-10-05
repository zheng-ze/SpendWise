import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spendwise/settings/display_preferences.dart';
import 'package:spendwise/settings/display_preferences_providers.dart';
import 'package:spendwise/settings/display_preferences_store.dart';
import 'package:spendwise/ui/shell/boot_chrome.dart';
import 'package:spendwise/ui/theme/spendwise_theme.dart';

Future<void> main() async {
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString(
      'assets/fonts/instrument_sans/OFL.txt',
    );
    yield LicenseEntryWithLineBreaks(const ['InstrumentSans'], license);
  });
  WidgetsFlutterBinding.ensureInitialized();
  final initial = await loadInitialDisplayPreferences();
  runApp(
    ProviderScope(
      overrides: [initialDisplayPreferencesProvider.overrideWithValue(initial)],
      child: const SpendWiseApp(),
    ),
  );
}

@visibleForTesting
Future<DisplayPreferences> loadInitialDisplayPreferences([
  Future<SharedPreferences> Function()? read,
]) async {
  try {
    final prefs = await (read ?? SharedPreferences.getInstance)();
    return DisplayPreferencesStore(prefs).load();
  } catch (error, stackTrace) {
    debugPrint('Display preferences preload failed: $error\n$stackTrace');
    return DisplayPreferences.defaults;
  }
}

ThemeMode themeModeFor(Appearance appearance) => switch (appearance) {
  Appearance.system => ThemeMode.system,
  Appearance.light => ThemeMode.light,
  Appearance.dark => ThemeMode.dark,
};

class SpendWiseApp extends ConsumerWidget {
  const SpendWiseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(
      displayPreferencesProvider.select(
        (preferences) => preferences.appearance,
      ),
    );
    return MaterialApp(
      title: 'SpendWise',
      theme: buildSpendWiseTheme(Brightness.light),
      darkTheme: buildSpendWiseTheme(Brightness.dark),
      themeMode: themeModeFor(appearance),
      home: const BootChrome(),
    );
  }
}
