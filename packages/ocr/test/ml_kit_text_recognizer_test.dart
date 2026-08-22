import 'dart:typed_data';
import 'dart:ui';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'
    as mlkit;
import 'package:ocr/ocr.dart';
import 'package:ocr/src/ml_kit_engine.dart';
import 'package:test/test.dart';

void main() {
  group('mapping a plugin result into RecognizedText', () {
    test('maps text, bounds, confidence and languages line by line', () async {
      final engine = _FakeMlKitEngine(
        mlkit.RecognizedText(
          text: 'ignored',
          blocks: [
            _block([
              _line(
                text: 'first line',
                rect: const Rect.fromLTRB(1, 2, 3, 4),
                confidence: 0.9,
                recognizedLanguages: const ['en'],
              ),
              _line(
                text: 'second line',
                rect: const Rect.fromLTRB(5, 6, 7, 8),
                confidence: 0.5,
                recognizedLanguages: const ['es'],
              ),
            ]),
          ],
        ),
      );
      final recognizer = MlKitTextRecognizer(engine: engine);

      final result = await recognizer.recognize(
        RecognizableImage(Uint8List(0)),
      );

      expect(result.lines, hasLength(2));
      expect(result.lines[0].text, 'first line');
      expect(
        result.lines[0].bounds,
        const RecognizedLineBounds(top: 2, bottom: 4, left: 1, right: 3),
      );
      expect(result.lines[0].confidence, 0.9);
      expect(result.lines[0].recognizedLanguages, ['en']);
      expect(result.lines[1].text, 'second line');
      expect(result.lines[1].confidence, 0.5);
      expect(result.lines[1].recognizedLanguages, ['es']);
    });

    test('flattens lines across multiple blocks, in order', () async {
      final engine = _FakeMlKitEngine(
        mlkit.RecognizedText(
          text: 'ignored',
          blocks: [
            _block([_line(text: 'block one line one')]),
            _block([
              _line(text: 'block two line one'),
              _line(text: 'block two line two'),
            ]),
          ],
        ),
      );
      final recognizer = MlKitTextRecognizer(engine: engine);

      final result = await recognizer.recognize(
        RecognizableImage(Uint8List(0)),
      );

      expect(result.lines.map((l) => l.text), [
        'block one line one',
        'block two line one',
        'block two line two',
      ]);
    });

    test('bounds are always populated from the plugin rect', () async {
      final engine = _FakeMlKitEngine(
        mlkit.RecognizedText(
          text: 'ignored',
          blocks: [
            _block([
              _line(text: 'x', rect: const Rect.fromLTRB(10, 20, 30, 40)),
            ]),
          ],
        ),
      );
      final recognizer = MlKitTextRecognizer(engine: engine);

      final result = await recognizer.recognize(
        RecognizableImage(Uint8List(0)),
      );

      expect(
        result.lines.single.bounds,
        const RecognizedLineBounds(top: 20, bottom: 40, left: 10, right: 30),
      );
    });

    group('confidence: Android-populated vs iOS-null, per the plugin contract', () {
      test(
        'a non-null confidence from the plugin (simulating Android) passes through',
        () async {
          final engine = _FakeMlKitEngine(
            mlkit.RecognizedText(
              text: 'ignored',
              blocks: [
                _block([_line(text: 'android line', confidence: 0.77)]),
              ],
            ),
          );
          final recognizer = MlKitTextRecognizer(engine: engine);

          final result = await recognizer.recognize(
            RecognizableImage(Uint8List(0)),
          );

          expect(result.lines.single.confidence, 0.77);
        },
      );

      test(
        'a null confidence from the plugin (simulating iOS) stays null, never backfilled',
        () async {
          final engine = _FakeMlKitEngine(
            mlkit.RecognizedText(
              text: 'ignored',
              blocks: [
                _block([_line(text: 'ios line', confidence: null)]),
              ],
            ),
          );
          final recognizer = MlKitTextRecognizer(engine: engine);

          final result = await recognizer.recognize(
            RecognizableImage(Uint8List(0)),
          );

          expect(result.lines.single.confidence, isNull);
        },
      );
    });

    test(
      'recognizedLanguages is empty, never null, when the plugin reports none',
      () async {
        final engine = _FakeMlKitEngine(
          mlkit.RecognizedText(
            text: 'ignored',
            blocks: [
              _block([
                _line(text: 'no languages', recognizedLanguages: const []),
              ]),
            ],
          ),
        );
        final recognizer = MlKitTextRecognizer(engine: engine);

        final result = await recognizer.recognize(
          RecognizableImage(Uint8List(0)),
        );

        expect(result.lines.single.recognizedLanguages, isEmpty);
      },
    );

    test(
      'an empty plugin result maps to an empty RecognizedText, not a failure',
      () async {
        final engine = _FakeMlKitEngine(
          mlkit.RecognizedText(text: '', blocks: []),
        );
        final recognizer = MlKitTextRecognizer(engine: engine);

        final result = await recognizer.recognize(
          RecognizableImage(Uint8List(0)),
        );

        expect(result.lines, isEmpty);
      },
    );
  });

  group('failure wrapping', () {
    test(
      'a plugin exception is wrapped in TextRecognitionFailure, never escapes as-is',
      () async {
        final engine = _ThrowingMlKitEngine(
          StateError('native recognizer crashed'),
        );
        final recognizer = MlKitTextRecognizer(engine: engine);

        await expectLater(
          recognizer.recognize(RecognizableImage(Uint8List(0))),
          throwsA(isA<TextRecognitionFailure>()),
        );
      },
    );

    test(
      'the failure message names the engine and the underlying cause',
      () async {
        final engine = _ThrowingMlKitEngine(
          StateError('native recognizer crashed'),
        );
        final recognizer = MlKitTextRecognizer(engine: engine);

        try {
          await recognizer.recognize(RecognizableImage(Uint8List(0)));
          fail('expected TextRecognitionFailure');
        } on TextRecognitionFailure catch (e) {
          expect(e.message, contains('ML Kit'));
          expect(e.message, contains('native recognizer crashed'));
        }
      },
    );
  });

  group('dispose', () {
    test('calls close on the underlying plugin engine', () async {
      final engine = _FakeMlKitEngine(
        mlkit.RecognizedText(text: '', blocks: []),
      );
      final recognizer = MlKitTextRecognizer(engine: engine);

      await recognizer.dispose();

      expect(engine.closed, isTrue);
    });
  });
}

mlkit.TextBlock _block(List<mlkit.TextLine> lines) {
  return mlkit.TextBlock(
    text: lines.map((l) => l.text).join('\n'),
    lines: lines,
    boundingBox: Rect.zero,
    recognizedLanguages: const [],
    cornerPoints: const [],
  );
}

mlkit.TextLine _line({
  required String text,
  Rect rect = Rect.zero,
  double? confidence,
  List<String> recognizedLanguages = const [],
}) {
  return mlkit.TextLine(
    text: text,
    elements: const [],
    boundingBox: rect,
    recognizedLanguages: recognizedLanguages,
    cornerPoints: const [],
    confidence: confidence,
    angle: null,
  );
}

class _FakeMlKitEngine implements MlKitEngine {
  _FakeMlKitEngine(this._result);

  final mlkit.RecognizedText _result;
  bool closed = false;

  @override
  Future<mlkit.RecognizedText> processImage(mlkit.InputImage inputImage) async {
    return _result;
  }

  @override
  Future<void> close() async {
    closed = true;
  }
}

class _ThrowingMlKitEngine implements MlKitEngine {
  _ThrowingMlKitEngine(this._error);

  final Object _error;

  @override
  Future<mlkit.RecognizedText> processImage(mlkit.InputImage inputImage) async {
    throw _error;
  }

  @override
  Future<void> close() async {}
}
