import 'package:flutter/services.dart';

/// The single engine call [AndroidTextRecognizer] needs from the native
/// ML Kit recognizer on Android.
abstract class AndroidEngine {
  /// Recognizes text in [imageBytes].
  ///
  /// Returns one map per recognized line. Each map holds `text` (String) and
  /// pixel-space, top-left-origin `left`, `top`, `right`, `bottom` (double).
  /// `confidence` (double, 0.0-1.0) is present only when ML Kit reports it;
  /// the Dart side reads it as a nullable field.
  Future<List<Map<Object?, Object?>>> recognizeText(Uint8List imageBytes);
}

/// Runs the real native ML Kit recognizer over the
/// `spendwise/android_text_recognizer` method channel.
class PluginAndroidEngine implements AndroidEngine {
  static const MethodChannel _channel = MethodChannel(
    'spendwise/android_text_recognizer',
  );

  @override
  Future<List<Map<Object?, Object?>>> recognizeText(
    Uint8List imageBytes,
  ) async {
    // invokeMethod only accepts dynamic as its decode type; invokeListMethod casts each element
    // itself, and Map<Object?, Object?> matches how the codec actually decodes a map.
    final result = await _channel.invokeListMethod<Map<Object?, Object?>>(
      'recognizeText',
      imageBytes,
    );
    // A null reply means the native side never produced a list: a malformed response, not "no
    // text found", so this fails rather than silently returning an empty list.
    if (result == null) {
      throw StateError('Android text-recognition channel returned null');
    }
    return result;
  }
}
