@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:ocr/ocr.dart' hide TesseractTextRecognizer, TesseractEngine;
import 'package:ocr/src/tesseract_text_recognizer_web.dart';
import 'package:web/web.dart' as web;

/// Matches the pinned release in `app/web/index.html`'s `<script>` tag and
/// `tesseract_text_recognizer_web.dart`'s `corePath`/`workerPath`/`langPath`.
/// This test lives in `packages/ocr/`, not `app/`, so it can't rely on
/// `app/web/index.html` — it loads the same script itself.
const _tesseractScriptUrl =
    'https://cdn.jsdelivr.net/npm/tesseract.js@7.0.0/dist/tesseract.min.js';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'recognizes text from a real receipt fixture via the real Tesseract.js engine',
    () async {
      await _loadTesseractScript();
      final imageData = await rootBundle.load(
        'test/fixtures/fixture_01_grocery_total_keyword.png',
      );
      final recognizer = TesseractTextRecognizer();

      final RecognizedText result;
      try {
        result = await recognizer.recognize(
          RecognizableImage(imageData.buffer.asUint8List()),
        );
      } finally {
        await recognizer.dispose();
      }

      expect(result.lines, isNotEmpty);
      expect(result.lines.any((line) => line.text.trim().isNotEmpty), isTrue);
      for (final line in result.lines) {
        expect(line.recognizedLanguages, isEmpty);
        if (line.confidence != null) {
          expect(line.confidence, inInclusiveRange(0.0, 1.0));
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

Future<void> _loadTesseractScript() async {
  final completer = Completer<void>();
  final script = web.document.createElement('script') as web.HTMLScriptElement;
  script.src = _tesseractScriptUrl;
  script.addEventListener(
    'load',
    (web.Event event) {
      completer.complete();
    }.toJS,
  );
  script.addEventListener(
    'error',
    (web.Event event) {
      completer.completeError(StateError('failed to load tesseract.js'));
    }.toJS,
  );
  web.document.head!.append(script);
  await completer.future;
}
