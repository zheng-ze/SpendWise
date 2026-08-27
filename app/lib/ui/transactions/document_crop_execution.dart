import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Crops [sourceBytes] (any format [ui.decodeImageFromList] can read) to
/// [rect], in the source image's own pixel coordinates, and returns PNG
/// bytes. [rect] is clamped to the source image's bounds first, so a
/// dragged handle that ended up outside the image never asks for pixels
/// that don't exist.
Future<Uint8List> cropToRect(Uint8List sourceBytes, Rect rect) async {
  final source = await _decodeImage(sourceBytes);
  final bounds = Rect.fromLTWH(
    0,
    0,
    source.width.toDouble(),
    source.height.toDouble(),
  );
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
  final byteData = await cropped.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}

Future<ui.Image> _decodeImage(Uint8List bytes) {
  final completer = Completer<ui.Image>();
  ui.decodeImageFromList(bytes, completer.complete);
  return completer.future;
}
