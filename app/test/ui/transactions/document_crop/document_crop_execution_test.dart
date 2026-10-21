import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ui/transactions/document_crop/document_crop_execution.dart';

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

  test('throws a descriptive error when PNG encoding yields no data', () async {
    final source = await _solidColorPng(50, 50, Colors.green);

    expect(
      () => cropToRect(
        source,
        const Rect.fromLTWH(0, 0, 20, 20),
        encodePng: (image) async => null,
      ),
      throwsA(
        isA<StateError>().having((e) => e.message, 'message', contains('PNG')),
      ),
    );
  });
}
