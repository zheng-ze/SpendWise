import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocr/ocr.dart';
import 'package:ocr/src/android/android_engine.dart';

void main() {
  // Needed for the PluginAndroidEngine channel test below, not the fake-engine tests above it.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('mapping a plugin result into RecognizedText', () {
    test('maps text, bounds and confidence line by line', () async {
      final engine = _FakeAndroidEngine([
        {
          'text': 'first line',
          'confidence': 0.9,
          'left': 1.0,
          'top': 2.0,
          'right': 3.0,
          'bottom': 4.0,
        },
        {
          'text': 'second line',
          'confidence': 0.5,
          'left': 5.0,
          'top': 6.0,
          'right': 7.0,
          'bottom': 8.0,
        },
      ]);
      final recognizer = AndroidTextRecognizer(engine: engine);

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
      expect(result.lines[1].text, 'second line');
      expect(result.lines[1].confidence, 0.5);
      expect(
        result.lines[1].bounds,
        const RecognizedLineBounds(top: 6, bottom: 8, left: 5, right: 7),
      );
    });

    test('confidence passes through unchanged', () async {
      final engine = _FakeAndroidEngine([
        {
          'text': 'line',
          'confidence': 0.77,
          'left': 1.0,
          'top': 2.0,
          'right': 3.0,
          'bottom': 4.0,
        },
      ]);
      final recognizer = AndroidTextRecognizer(engine: engine);

      final result = await recognizer.recognize(
        RecognizableImage(Uint8List(0)),
      );

      expect(result.lines.single.confidence, 0.77);
    });

    test('bounds come from the four numeric fields directly', () async {
      final engine = _FakeAndroidEngine([
        {
          'text': 'x',
          'confidence': 0.3,
          'left': 10.0,
          'top': 20.0,
          'right': 30.0,
          'bottom': 40.0,
        },
      ]);
      final recognizer = AndroidTextRecognizer(engine: engine);

      final result = await recognizer.recognize(
        RecognizableImage(Uint8List(0)),
      );

      expect(
        result.lines.single.bounds,
        const RecognizedLineBounds(top: 20, bottom: 40, left: 10, right: 30),
      );
    });

    test('a missing language maps to an empty list rather than null', () async {
      final engine = _FakeAndroidEngine([
        {
          'text': 'a',
          'confidence': 0.1,
          'left': 1.0,
          'top': 2.0,
          'right': 3.0,
          'bottom': 4.0,
        },
      ]);
      final recognizer = AndroidTextRecognizer(engine: engine);

      final result = await recognizer.recognize(
        RecognizableImage(Uint8List(0)),
      );

      expect(result.lines.single.recognizedLanguages, isEmpty);
      expect(result.lines.single.recognizedLanguages, isNot(isNull));
    });

    test(
      'a present language passes through as a single-element list',
      () async {
        final engine = _FakeAndroidEngine([
          {
            'text': 'b',
            'confidence': 0.2,
            'left': 5.0,
            'top': 6.0,
            'right': 7.0,
            'bottom': 8.0,
            'language': 'en',
          },
        ]);
        final recognizer = AndroidTextRecognizer(engine: engine);

        final result = await recognizer.recognize(
          RecognizableImage(Uint8List(0)),
        );

        expect(result.lines.single.recognizedLanguages, ['en']);
      },
    );

    test('a missing confidence maps to null rather than throwing', () async {
      // The base recognizer does not report a confidence for every line, so
      // the engine payload can omit the key entirely.
      final engine = _FakeAndroidEngine([
        {
          'text': 'no confidence',
          'left': 1.0,
          'top': 2.0,
          'right': 3.0,
          'bottom': 4.0,
        },
      ]);
      final recognizer = AndroidTextRecognizer(engine: engine);

      final result = await recognizer.recognize(
        RecognizableImage(Uint8List(0)),
      );

      expect(result.lines.single.confidence, isNull);
    });

    test(
      'an empty engine result maps to an empty RecognizedText, not a failure',
      () async {
        final engine = _FakeAndroidEngine([]);
        final recognizer = AndroidTextRecognizer(engine: engine);

        final result = await recognizer.recognize(
          RecognizableImage(Uint8List(0)),
        );

        expect(result.lines, isEmpty);
        expect(result, isA<RecognizedText>());
      },
    );
  });

  group('failure wrapping', () {
    test(
      'an engine exception is wrapped in TextRecognitionFailure, never escapes as-is',
      () async {
        final engine = _ThrowingAndroidEngine(
          StateError('native recognizer crashed'),
        );
        final recognizer = AndroidTextRecognizer(engine: engine);

        await expectLater(
          recognizer.recognize(RecognizableImage(Uint8List(0))),
          throwsA(isA<TextRecognitionFailure>()),
        );
      },
    );

    test(
      'the failure message names the engine and the underlying cause',
      () async {
        final engine = _ThrowingAndroidEngine(
          StateError('native recognizer crashed'),
        );
        final recognizer = AndroidTextRecognizer(engine: engine);

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
    test('makes no call against the engine (no-op is intentional)', () async {
      final engine = _RecordingAndroidEngine();
      final recognizer = AndroidTextRecognizer(engine: engine);

      await recognizer.dispose();

      expect(engine.recognizeCallCount, 0);
      expect(engine.disposeCallCount, 0);
    });
  });

  group('PluginAndroidEngine channel decoding', () {
    test(
      'a null channel response (not an empty list) throws, per the channel contract',
      () async {
        // flutter_test resets mock channel handlers between tests automatically.
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('spendwise/android_text_recognizer'),
              (MethodCall call) async {
                // A successful reply carrying no list: the native side never
                // produced one.
                return null;
              },
            );

        final engine = PluginAndroidEngine();
        await expectLater(
          engine.recognizeText(Uint8List(0)),
          throwsA(isA<StateError>()),
        );
      },
    );
  });
}

class _FakeAndroidEngine implements AndroidEngine {
  _FakeAndroidEngine(this._result);

  final List<Map<Object?, Object?>> _result;

  @override
  Future<List<Map<Object?, Object?>>> recognizeText(
    Uint8List imageBytes,
  ) async {
    return _result;
  }
}

class _ThrowingAndroidEngine implements AndroidEngine {
  _ThrowingAndroidEngine(this._error);

  final Object _error;

  @override
  Future<List<Map<Object?, Object?>>> recognizeText(
    Uint8List imageBytes,
  ) async {
    throw _error;
  }
}

class _RecordingAndroidEngine implements AndroidEngine {
  int recognizeCallCount = 0;
  int disposeCallCount = 0;

  @override
  Future<List<Map<Object?, Object?>>> recognizeText(
    Uint8List imageBytes,
  ) async {
    recognizeCallCount++;
    return const [];
  }
}
