import 'recognizable_image.dart';
import 'recognized_text.dart';
import 'text_recognition_failure.dart';

/// Engine-swappable seam: implementations wrap a specific engine and map
/// its result into [RecognizedText].
abstract class TextRecognizer {
  /// Throws [TextRecognitionFailure] if the engine can't run. Never returns
  /// an empty result to signal failure, so "ran and found nothing" and
  /// "couldn't run" stay distinguishable to the caller.
  Future<RecognizedText> recognize(RecognizableImage image);

  /// Releases whatever resource the engine holds (a native recognizer
  /// instance, a worker thread). The caller owns this recognizer's lifetime
  /// and must call this when done with it.
  Future<void> dispose();
}
