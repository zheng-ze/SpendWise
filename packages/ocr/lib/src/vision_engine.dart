import 'package:flutter/services.dart';

/// The single engine call [VisionTextRecognizer] needs from the native
/// Vision recognizer.
abstract class VisionEngine {
  /// Recognizes text in [imageBytes].
  ///
  /// Returns one map per recognized line. Each map holds `text` (String),
  /// `confidence` (double), and pixel-space, top-left-origin `left`, `top`,
  /// `right`, `bottom` (double). There is no `recognizedLanguages` key: the
  /// recognizer never reports one.
  Future<List<Map<Object?, Object?>>> recognizeText(Uint8List imageBytes);
}

/// Runs the real native Vision recognizer over the
/// `spendwise/vision_text_recognizer` method channel.
class PluginVisionEngine implements VisionEngine {
  static const MethodChannel _channel = MethodChannel(
    'spendwise/vision_text_recognizer',
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
      throw StateError('Vision channel returned null');
    }
    return result;
  }
}
