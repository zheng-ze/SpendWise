import 'android_engine.dart';
import '../recognizable_image.dart';
import '../recognized_line.dart';
import '../recognized_line_bounds.dart';
import '../recognized_text.dart';
import '../text_recognition_failure.dart';
import '../text_recognizer.dart';

/// Recognizes text in an image using Android's on-device ML Kit recognizer,
/// reached through [AndroidEngine].
class AndroidTextRecognizer implements TextRecognizer {
  AndroidTextRecognizer({AndroidEngine? engine})
    : _engine = engine ?? PluginAndroidEngine();

  final AndroidEngine _engine;

  @override
  Future<RecognizedText> recognize(RecognizableImage image) async {
    try {
      final result = await _engine.recognizeText(image.bytes);
      return _toRecognizedText(result);
    } catch (e) {
      // Untyped catch is deliberate here: the platform channel can throw
      // PlatformException, MissingPluginException, or an arbitrary native
      // error, none of which this package can enumerate in advance.
      throw TextRecognitionFailure('ML Kit: $e');
    }
  }

  @override
  Future<void> dispose() async {
    // No-op: ML Kit issues one-shot requests with no persistent resource to
    // release, unlike the plugin's long-lived recognizer instance.
  }
}

RecognizedText _toRecognizedText(List<Map<Object?, Object?>> result) {
  final lines = <RecognizedLine>[
    for (final entry in result) _toRecognizedLine(entry),
  ];
  return RecognizedText(lines);
}

RecognizedLine _toRecognizedLine(Map<Object?, Object?> entry) {
  return RecognizedLine(
    text: entry['text'] as String,
    bounds: RecognizedLineBounds(
      top: entry['top'] as double,
      bottom: entry['bottom'] as double,
      left: entry['left'] as double,
      right: entry['right'] as double,
    ),
    // ML Kit confidence may be absent, so read it as nullable rather than
    // forcing a non-null cast like the Vision side does.
    confidence: entry['confidence'] as double?,
    // ML Kit reports at most one language per line; the key is absent when
    // it could not determine one.
    recognizedLanguages: switch (entry['language']) {
      final String language => [language],
      _ => const [],
    },
  );
}
