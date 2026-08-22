import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'
    as mlkit;

/// The two plugin calls [MlKitTextRecognizer] needs from the ML Kit text
/// recognizer.
abstract class MlKitEngine {
  Future<mlkit.RecognizedText> processImage(mlkit.InputImage inputImage);
  Future<void> close();
}

/// Runs the real ML Kit plugin recognizer.
class PluginMlKitEngine implements MlKitEngine {
  PluginMlKitEngine() : _recognizer = mlkit.TextRecognizer();

  final mlkit.TextRecognizer _recognizer;

  @override
  Future<mlkit.RecognizedText> processImage(mlkit.InputImage inputImage) {
    return _recognizer.processImage(inputImage);
  }

  @override
  Future<void> close() => _recognizer.close();
}
