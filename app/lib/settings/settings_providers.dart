import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ocr/field_extraction_readiness.dart';
import 'package:spendwise/settings/app_settings.dart';

final appSettingsProvider = Provider<AppSettings>((ref) => const AppSettings());

final scanStripEnabledProvider = FutureProvider<bool>((ref) {
  return ref.watch(appSettingsProvider).scanStripEnabled();
});

final fieldExtractionReadyProvider = FutureProvider<bool>((ref) {
  return isFieldExtractionReady();
});
