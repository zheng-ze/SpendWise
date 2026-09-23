import 'package:flutter/foundation.dart';
import 'package:ocr/ocr.dart';

import 'platform_adapter_selection.dart';

typedef TextRecognizerFactory = TextRecognizer Function();

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
