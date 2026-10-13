import 'package:flutter/material.dart';

// MARK: - Constants

const _imageOrigin = Offset.zero;
const _imageEdge = 0.0;

// MARK: - DocumentCorners
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

// MARK: - Helpers
DocumentCorners initialCorners(Size imageSize) {
  return DocumentCorners(
    topLeft: _imageOrigin,
    topRight: Offset(imageSize.width, _imageEdge),
    bottomRight: Offset(imageSize.width, imageSize.height),
    bottomLeft: Offset(_imageEdge, imageSize.height),
  );
}

Offset clampToImage(Offset point, Size imageSize) {
  return Offset(
    point.dx.clamp(_imageEdge, imageSize.width),
    point.dy.clamp(_imageEdge, imageSize.height),
  );
}

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
