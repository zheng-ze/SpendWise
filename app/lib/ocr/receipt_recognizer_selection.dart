import 'package:flutter/foundation.dart';
import 'package:ocr/ocr.dart';

import 'ios_platform_check.dart';
import 'platform_adapter_selection.dart';

/// Picks the recognizer for the current platform, or null if the platform
/// has none yet. [isWeb] and [isIOS] let a test fix the branch instead of
/// reading the real platform.
TextRecognizer? selectRecognizer({bool? isWeb, bool? isIOS}) {
  // dart:io's platform checks don't run on web, so that branch is checked
  // first.
  if (isWeb ?? kIsWeb) return TesseractTextRecognizer();
  return selectPlatformAdapter<TextRecognizer>(<TextRecognizer? Function()>[
    () => (isIOS ?? isIOSPlatform) ? VisionTextRecognizer() : null,
    () => AndroidTextRecognizer(),
  ]);
}
