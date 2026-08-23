import 'package:flutter/foundation.dart';
import 'package:ocr/ocr.dart';

/// Picks the recognizer for the current platform, or null if the platform
/// has none yet. [isWeb] lets a test fix the branch instead of reading the
/// real constant.
TextRecognizer? selectRecognizer({bool? isWeb}) {
  // dart:io's platform checks don't run on web, so that branch is checked
  // first and left with no engine until one is built.
  if (isWeb ?? kIsWeb) return null;
  return MlKitTextRecognizer();
}
