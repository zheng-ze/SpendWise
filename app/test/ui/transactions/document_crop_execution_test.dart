import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ui/transactions/document_crop_execution.dart';

Future<ui.Image> _decodeImage(Uint8List bytes) {
  final completer = Completer<ui.Image>();
  ui.decodeImageFromList(bytes, completer.complete);
  return completer.future;
}

Future<Uint8List> _solidColorPng(int width, int height, ui.Color color) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = color,
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('crops the image to the given rect, in image pixel coordinates', () async {
    final source = await _solidColorPng(100, 100, Colors.blue);

    final cropped = await cropToRect(
      source,
      const Rect.fromLTWH(10, 10, 40, 30),
    );

    final decoded = await _decodeImage(cropped);
    expect(decoded.width, 40);
    expect(decoded.height, 30);
  });

  test('clamps a rect that extends past the source image bounds', () async {
    final source = await _solidColorPng(50, 50, Colors.red);

    final cropped = await cropToRect(
      source,
      const Rect.fromLTWH(30, 30, 40, 40),
    );

    final decoded = await _decodeImage(cropped);
    expect(decoded.width, 20);
    expect(decoded.height, 20);
  });
}
