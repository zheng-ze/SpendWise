import 'package:meta/meta.dart';

/// Bounding box of a recognized line, in the source image's coordinate space.
@immutable
class RecognizedLineBounds {
  const RecognizedLineBounds({
    required this.top,
    required this.bottom,
    required this.left,
    required this.right,
  });

  final double top;
  final double bottom;
  final double left;
  final double right;

  double get height => bottom - top;

  @override
  bool operator ==(Object other) {
    return other is RecognizedLineBounds &&
        other.top == top &&
        other.bottom == bottom &&
        other.left == left &&
        other.right == right;
  }

  @override
  int get hashCode => Object.hash(top, bottom, left, right);

  @override
  String toString() => 'RecognizedLineBounds($left, $top, $right, $bottom)';
}
