import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'
    as mlkit;

import 'ml_kit_engine.dart';
import 'recognizable_image.dart';
import 'recognized_line.dart';
import 'recognized_line_bounds.dart';
import 'recognized_text.dart';
import 'text_recognition_failure.dart';
import 'text_recognizer.dart';

/// Wraps `google_mlkit_text_recognition` for iOS and Android. Same call
/// shape on both platforms; this class does no platform checks itself.
class MlKitTextRecognizer implements TextRecognizer {
  MlKitTextRecognizer({MlKitEngine? engine})
    : _engine = engine ?? PluginMlKitEngine();

  final MlKitEngine _engine;

  @override
  Future<RecognizedText> recognize(RecognizableImage image) async {
    final file = await _writeToTempFile(image);
    try {
      final mlkit.RecognizedText result;
      try {
        result = await _engine.processImage(
          mlkit.InputImage.fromFilePath(file.path),
        );
      } catch (e) {
        throw TextRecognitionFailure('ML Kit: $e');
      }
      return _toRecognizedText(result);
    } finally {
      await file.delete();
    }
  }

  @override
  Future<void> dispose() => _engine.close();
}

/// The plugin only accepts encoded image bytes as a file path, not as raw
/// bytes (its bytes constructor is for unencoded pixel planes), so this
/// writes the image to a scratch file the plugin can read.
Future<File> _writeToTempFile(RecognizableImage image) async {
  final file = File(
    '${Directory.systemTemp.path}/ocr_ml_kit_${DateTime.now().microsecondsSinceEpoch}.img',
  );
  return file.writeAsBytes(image.bytes);
}

RecognizedText _toRecognizedText(mlkit.RecognizedText result) {
  final lines = <RecognizedLine>[
    for (final block in result.blocks)
      for (final line in block.lines) _toRecognizedLine(line),
  ];
  return RecognizedText(lines);
}

RecognizedLine _toRecognizedLine(mlkit.TextLine line) {
  return RecognizedLine(
    text: line.text,
    bounds: RecognizedLineBounds(
      top: line.boundingBox.top,
      bottom: line.boundingBox.bottom,
      left: line.boundingBox.left,
      right: line.boundingBox.right,
    ),
    confidence: line.confidence,
    recognizedLanguages: line.recognizedLanguages,
  );
}
