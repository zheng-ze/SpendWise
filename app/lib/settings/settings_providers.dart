import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/settings/app_settings.dart';

final appSettingsProvider = Provider<AppSettings>((ref) => const AppSettings());

final scanStripEnabledProvider = FutureProvider<bool>((ref) {
  return ref.watch(appSettingsProvider).scanStripEnabled();
});
