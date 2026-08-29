import 'package:flutter/material.dart';

/// The four corner handles of the web crop screen, in image display
/// coordinates (the same coordinate space the decoded image is painted in).
@immutable
class DocumentCorners {
  const DocumentCorners({
    required this.topLeft,
    required this.topRight,
    required this.bottomRight,
    required this.bottomLeft,
  });

  final Offset topLeft;
  final Offset topRight;
  final Offset bottomRight;
  final Offset bottomLeft;

  List<Offset> get points => [topLeft, topRight, bottomRight, bottomLeft];

  DocumentCorners copyWith({
    Offset? topLeft,
    Offset? topRight,
    Offset? bottomRight,
    Offset? bottomLeft,
  }) {
    return DocumentCorners(
      topLeft: topLeft ?? this.topLeft,
      topRight: topRight ?? this.topRight,
      bottomRight: bottomRight ?? this.bottomRight,
      bottomLeft: bottomLeft ?? this.bottomLeft,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DocumentCorners &&
      other.topLeft == topLeft &&
      other.topRight == topRight &&
      other.bottomRight == bottomRight &&
      other.bottomLeft == bottomLeft;

  @override
  int get hashCode => Object.hash(topLeft, topRight, bottomRight, bottomLeft);
}

/// Starting handle positions: the image's own four corners.
DocumentCorners initialCorners(Size imageSize) {
  return DocumentCorners(
    topLeft: Offset.zero,
    topRight: Offset(imageSize.width, 0),
    bottomRight: Offset(imageSize.width, imageSize.height),
    bottomLeft: Offset(0, imageSize.height),
  );
}

/// Keeps a dragged handle within the image, so a corner can never end up
/// pointing outside the picture it's cropping.
Offset clampToImage(Offset point, Size imageSize) {
  return Offset(
    point.dx.clamp(0, imageSize.width),
    point.dy.clamp(0, imageSize.height),
  );
}

/// The smallest axis-aligned rect containing all four corners. Used as the
/// crop region when a full perspective warp isn't available.
Rect boundingRect(DocumentCorners corners) {
  final xs = corners.points.map((p) => p.dx);
  final ys = corners.points.map((p) => p.dy);
  return Rect.fromLTRB(
    xs.reduce((a, b) => a < b ? a : b),
    ys.reduce((a, b) => a < b ? a : b),
    xs.reduce((a, b) => a > b ? a : b),
    ys.reduce((a, b) => a > b ? a : b),
  );
}
