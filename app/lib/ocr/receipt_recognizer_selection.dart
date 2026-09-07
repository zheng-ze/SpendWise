import 'package:flutter/foundation.dart';
import 'package:ocr/ocr.dart';

import 'platform_adapter_selection.dart';

/// Factory for a platform-specific recognizer.
typedef TextRecognizerFactory = TextRecognizer Function();

/// Picks the recognizer for the current platform, or null if the platform
/// has none yet. [isIOS] and [isAndroid] let a test fix the branch instead of
/// reading the real platform; the [visionFactory] and [androidFactory]
/// parameters let a test inject fakes.
TextRecognizer? selectRecognizer({
  bool? isIOS,
  bool? isAndroid,
  TextRecognizerFactory visionFactory = VisionTextRecognizer.new,
  TextRecognizerFactory androidFactory = AndroidTextRecognizer.new,
}) {
  return selectPlatformAdapter<TextRecognizer>(<TextRecognizer? Function()>[
    () => (isIOS ?? defaultTargetPlatform == TargetPlatform.iOS)
        ? visionFactory()
        : null,
    () => (isAndroid ?? defaultTargetPlatform == TargetPlatform.android)
        ? androidFactory()
        : null,
  ]);
}
