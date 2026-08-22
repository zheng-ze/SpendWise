import 'package:meta/meta.dart';

/// Thrown by a recognizer's `recognize` call when the engine cannot produce
/// a result (decode failure, plugin unavailable, native crash). [message]
/// combines the engine name and the underlying cause; it's for logs and
/// debugging, never shown to the user directly.
@immutable
class TextRecognitionFailure implements Exception {
  const TextRecognitionFailure(this.message);

  final String message;

  @override
  bool operator ==(Object other) {
    return other is TextRecognitionFailure && other.message == message;
  }

  @override
  int get hashCode => message.hashCode;

  @override
  String toString() => 'TextRecognitionFailure: $message';
}
