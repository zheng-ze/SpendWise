import 'package:meta/meta.dart';

import 'recognized_line.dart';

/// The full result of one recognition call: a flat list of lines, in the
/// order the engine returned them.
@immutable
class RecognizedText {
  RecognizedText(List<RecognizedLine> lines) : lines = List.unmodifiable(lines);

  final List<RecognizedLine> lines;

  @override
  bool operator ==(Object other) {
    return other is RecognizedText && _listEquals(other.lines, lines);
  }

  @override
  int get hashCode => Object.hashAll(lines);

  @override
  String toString() => 'RecognizedText(${lines.length} lines)';
}

bool _listEquals(List<RecognizedLine> a, List<RecognizedLine> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
