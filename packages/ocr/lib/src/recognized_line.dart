import 'package:meta/meta.dart';

import 'recognized_line_bounds.dart';

/// One line of recognized text. [bounds] and [confidence] are null, and
/// [recognizedLanguages] is empty, when the engine that produced this line
/// doesn't expose that data.
@immutable
class RecognizedLine {
  RecognizedLine({
    required this.text,
    this.bounds,
    this.confidence,
    List<String> recognizedLanguages = const [],
  }) : recognizedLanguages = List.unmodifiable(recognizedLanguages);

  final String text;
  final RecognizedLineBounds? bounds;

  /// 0.0-1.0, or null when the engine doesn't report a confidence score.
  final double? confidence;

  /// BCP-47 language codes. Empty, never null, when the engine has no
  /// output-side language identification.
  final List<String> recognizedLanguages;

  @override
  bool operator ==(Object other) {
    return other is RecognizedLine &&
        other.text == text &&
        other.bounds == bounds &&
        other.confidence == confidence &&
        _listEquals(other.recognizedLanguages, recognizedLanguages);
  }

  @override
  int get hashCode => Object.hash(
    text,
    bounds,
    confidence,
    Object.hashAll(recognizedLanguages),
  );

  @override
  String toString() => 'RecognizedLine($text)';
}

bool _listEquals(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
