import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ui/transactions/document_crop_geometry.dart';

void main() {
  group('initialCorners', () {
    test('starts at the image\'s own four corners', () {
      final corners = initialCorners(const Size(200, 100));

      expect(corners.topLeft, const Offset(0, 0));
      expect(corners.topRight, const Offset(200, 0));
      expect(corners.bottomRight, const Offset(200, 100));
      expect(corners.bottomLeft, const Offset(0, 100));
    });
  });

  group('clampToImage', () {
    test('leaves a point already inside the image untouched', () {
      final clamped = clampToImage(const Offset(50, 40), const Size(200, 100));

      expect(clamped, const Offset(50, 40));
    });

    test('clamps a point dragged past the image edges', () {
      final clamped = clampToImage(
        const Offset(-20, 150),
        const Size(200, 100),
      );

      expect(clamped, const Offset(0, 100));
    });
  });

  group('boundingRect', () {
    test('computes the smallest rect containing all four corners', () {
      const corners = DocumentCorners(
        topLeft: Offset(10, 5),
        topRight: Offset(180, 20),
        bottomRight: Offset(190, 90),
        bottomLeft: Offset(5, 95),
      );

      final rect = boundingRect(corners);

      expect(rect, const Rect.fromLTRB(5, 5, 190, 95));
    });
  });
}
