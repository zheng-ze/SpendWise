import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Encodes [image] as PNG bytes, or null if the engine could not encode it.
/// [cropToRect] takes this as a constructor-style parameter so a test can
/// exercise the null-result path without a real encoding failure.
typedef PngEncoder = Future<ByteData?> Function(ui.Image image);

Future<ByteData?> _defaultPngEncoder(ui.Image image) =>
    image.toByteData(format: ui.ImageByteFormat.png);

/// Crops [sourceBytes] to [rect], in the source image's own pixel
/// coordinates, and returns PNG bytes. Clamps [rect] to the image bounds.
Future<Uint8List> cropToRect(
  Uint8List sourceBytes,
  Rect rect, {
  PngEncoder encodePng = _defaultPngEncoder,
}) async {
  final source = await _decodeImage(sourceBytes);
  final bounds = Rect.fromLTWH(
    0,
    0,
    source.width.toDouble(),
    source.height.toDouble(),
  );
  // A dragged handle can end up outside the image; clamping keeps this from
  // asking for pixels that don't exist.
  final clamped = rect.intersect(bounds);

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawImageRect(
    source,
    clamped,
    Rect.fromLTWH(0, 0, clamped.width, clamped.height),
    Paint(),
  );
  final picture = recorder.endRecording();
  final cropped = await picture.toImage(
    clamped.width.round(),
    clamped.height.round(),
  );
  final byteData = await encodePng(cropped);
  if (byteData == null) {
    throw StateError('Failed to encode cropped image as PNG.');
  }
  return byteData.buffer.asUint8List();
}

Future<ui.Image> _decodeImage(Uint8List bytes) {
  final completer = Completer<ui.Image>();
  ui.decodeImageFromList(bytes, completer.complete);
  return completer.future;
}
