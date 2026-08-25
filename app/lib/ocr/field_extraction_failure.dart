import 'package:meta/meta.dart';

/// Thrown by a [FieldExtractor] method when the underlying engine cannot
/// produce a result (session/runtime error, model unavailable mid-call).
/// [message] combines the engine name and the underlying cause; it's for
/// logs and debugging, never shown to the user directly.
@immutable
class FieldExtractionFailure implements Exception {
  const FieldExtractionFailure(this.message);

  final String message;

  @override
  bool operator ==(Object other) {
    return other is FieldExtractionFailure && other.message == message;
  }

  @override
  int get hashCode => message.hashCode;

  @override
  String toString() => 'FieldExtractionFailure: $message';
}
