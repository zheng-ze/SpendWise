@TestOn('browser')
library;

import 'dart:typed_data';

import 'package:ocr/ocr.dart' hide TesseractTextRecognizer, TesseractEngine;
import 'package:ocr/src/tesseract_text_recognizer_web.dart';
import 'package:test/test.dart';

void main() {
  group('mapping a fake engine result into RecognizedText', () {
    test('requests block geometry from the engine', () async {
      final engine = _FakeTesseractEngine({'blocks': <Object?>[]});
      final recognizer = TesseractTextRecognizer(engine: engine);

      await recognizer.recognize(RecognizableImage(Uint8List(0)));

      expect(engine.requestedBlocks, isTrue);
    });

    test(
      'flattens a nested block/paragraph/line result into lines, in order',
      () async {
        final engine = _FakeTesseractEngine({
          'blocks': [
            _block([
              _paragraph([_line(text: 'block one line one')]),
            ]),
            _block([
              _paragraph([
                _line(text: 'block two line one'),
                _line(text: 'block two line two'),
              ]),
            ]),
          ],
        });
        final recognizer = TesseractTextRecognizer(engine: engine);

        final result = await recognizer.recognize(
          RecognizableImage(Uint8List(0)),
        );

        expect(result.lines.map((RecognizedLine l) => l.text), [
          'block one line one',
          'block two line one',
          'block two line two',
        ]);
      },
    );

    test('confidence 87 maps to 0.87', () async {
      final engine = _FakeTesseractEngine({
        'blocks': [
          _block([
            _paragraph([_line(text: 'x', confidence: 87)]),
          ]),
        ],
      });
      final recognizer = TesseractTextRecognizer(engine: engine);

      final result = await recognizer.recognize(
        RecognizableImage(Uint8List(0)),
      );

      expect(result.lines.single.confidence, 0.87);
    });

    test(
      'geometry prefers rowAttributes.rowHeight over the bbox height',
      () async {
        final engine = _FakeTesseractEngine({
          'blocks': [
            _block([
              _paragraph([
                _line(
                  text: 'x',
                  rowHeight: 5,
                  bbox: const (x0: 1, y0: 2, x1: 3, y1: 100),
                ),
              ]),
            ]),
          ],
        });
        final recognizer = TesseractTextRecognizer(engine: engine);

        final result = await recognizer.recognize(
          RecognizableImage(Uint8List(0)),
        );

        expect(
          result.lines.single.bounds,
          const RecognizedLineBounds(top: 2, bottom: 7, left: 1, right: 3),
        );
      },
    );

    test(
      'geometry falls back to bbox height when rowHeight is absent',
      () async {
        final engine = _FakeTesseractEngine({
          'blocks': [
            _block([
              _paragraph([
                _line(text: 'x', bbox: const (x0: 1, y0: 2, x1: 3, y1: 10)),
              ]),
            ]),
          ],
        });
        final recognizer = TesseractTextRecognizer(engine: engine);

        final result = await recognizer.recognize(
          RecognizableImage(Uint8List(0)),
        );

        expect(
          result.lines.single.bounds,
          const RecognizedLineBounds(top: 2, bottom: 10, left: 1, right: 3),
        );
      },
    );

    test(
      'geometry is null, not a failure, when neither rowHeight nor bbox is present',
      () async {
        final engine = _FakeTesseractEngine({
          'blocks': [
            _block([
              _paragraph([_line(text: 'x')]),
            ]),
          ],
        });
        final recognizer = TesseractTextRecognizer(engine: engine);

        final result = await recognizer.recognize(
          RecognizableImage(Uint8List(0)),
        );

        expect(result.lines.single.bounds, isNull);
      },
    );

    test('recognizedLanguages is always empty', () async {
      final engine = _FakeTesseractEngine({
        'blocks': [
          _block([
            _paragraph([_line(text: 'x')]),
          ]),
        ],
      });
      final recognizer = TesseractTextRecognizer(engine: engine);

      final result = await recognizer.recognize(
        RecognizableImage(Uint8List(0)),
      );

      expect(result.lines.single.recognizedLanguages, isEmpty);
    });

    test('a result with no blocks maps to an empty RecognizedText', () async {
      final engine = _FakeTesseractEngine({'blocks': <Object?>[]});
      final recognizer = TesseractTextRecognizer(engine: engine);

      final result = await recognizer.recognize(
        RecognizableImage(Uint8List(0)),
      );

      expect(result.lines, isEmpty);
    });
  });

  group('failure wrapping', () {
    test(
      'an engine error during worker creation is wrapped in TextRecognitionFailure',
      () async {
        final engine = _ThrowingTesseractEngine(StateError('WASM load failed'));
        final recognizer = TesseractTextRecognizer(engine: engine);

        await expectLater(
          recognizer.recognize(RecognizableImage(Uint8List(0))),
          throwsA(isA<TextRecognitionFailure>()),
        );
      },
    );

    test(
      'an engine error during recognition is wrapped in TextRecognitionFailure naming the engine and cause',
      () async {
        final engine = _ThrowingTesseractEngine(StateError('worker crashed'));
        final recognizer = TesseractTextRecognizer(engine: engine);

        try {
          await recognizer.recognize(RecognizableImage(Uint8List(0)));
          fail('expected TextRecognitionFailure');
        } on TextRecognitionFailure catch (e) {
          expect(e.message, contains('Tesseract'));
          expect(e.message, contains('worker crashed'));
        }
      },
    );
  });

  group('dispose', () {
    test('terminates the underlying worker', () async {
      final engine = _FakeTesseractEngine({'blocks': <Object?>[]});
      final recognizer = TesseractTextRecognizer(engine: engine);

      await recognizer.dispose();

      expect(engine.terminateCalls, 1);
    });
  });
}

Map<String, Object?> _block(List<Map<String, Object?>> paragraphs) {
  return {'paragraphs': paragraphs};
}

Map<String, Object?> _paragraph(List<Map<String, Object?>> lines) {
  return {'lines': lines};
}

Map<String, Object?> _line({
  required String text,
  num? confidence,
  num? rowHeight,
  ({num x0, num y0, num x1, num y1})? bbox,
}) {
  return {
    'text': text,
    'confidence': confidence,
    if (rowHeight != null) 'rowAttributes': {'rowHeight': rowHeight},
    if (bbox != null)
      'bbox': {'x0': bbox.x0, 'y0': bbox.y0, 'x1': bbox.x1, 'y1': bbox.y1},
  };
}

class _FakeTesseractEngine implements TesseractEngine {
  _FakeTesseractEngine(this._result);

  final Map<String, Object?> _result;
  bool requestedBlocks = false;
  int terminateCalls = 0;

  @override
  Future<Map<String, Object?>> recognize(
    Uint8List bytes, {
    required bool blocks,
  }) async {
    requestedBlocks = blocks;
    return _result;
  }

  @override
  Future<void> terminate() async {
    terminateCalls++;
  }
}

class _ThrowingTesseractEngine implements TesseractEngine {
  _ThrowingTesseractEngine(this._error);

  final Object _error;

  @override
  Future<Map<String, Object?>> recognize(
    Uint8List bytes, {
    required bool blocks,
  }) async {
    throw _error;
  }

  @override
  Future<void> terminate() async {}
}
