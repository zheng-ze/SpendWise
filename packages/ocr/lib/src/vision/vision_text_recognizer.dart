import 'vision_engine.dart';
import '../recognizable_image.dart';
import '../recognized_line.dart';
import '../recognized_line_bounds.dart';
import '../recognized_text.dart';
import '../text_recognition_failure.dart';
import '../text_recognizer.dart';

/// Recognizes text in an image using the native Apple Vision recognizer,
/// reached through [VisionEngine].
class VisionTextRecognizer implements TextRecognizer {
  VisionTextRecognizer({VisionEngine? engine})
    : _engine = engine ?? PluginVisionEngine();

  final VisionEngine _engine;

  @override
  Future<RecognizedText> recognize(RecognizableImage image) async {
    try {
      final result = await _engine.recognizeText(image.bytes);
      return _toRecognizedText(result);
    } catch (e) {
      throw TextRecognitionFailure('Vision: $e');
    }
  }

  @override
  Future<void> dispose() async {
    // No-op: Vision issues one-shot requests with no persistent resource to
    // release, unlike Android's process-scoped ML Kit recognizer instance.
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
    confidence: entry['confidence'] as double,
    // Vision has no output-side language field; set it empty entirely here
    // rather than reading a key that is not in the payload.
    recognizedLanguages: const [],
  );
}
