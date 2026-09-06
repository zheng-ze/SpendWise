import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'recognizable_image.dart';
import 'recognized_line.dart';
import 'recognized_line_bounds.dart';
import 'recognized_text.dart';
import 'text_recognition_failure.dart';
import 'text_recognizer.dart';

/// The engine calls [TesseractTextRecognizer] needs from Tesseract.js.
///
/// Kept free of any JS-interop types so both this and the native stub's
/// identical interface, plus a hand-written fake used by browser-run unit
/// tests, stay implementable without every caller needing web imports.
/// [recognize] returns Tesseract.js's page result as a plain Dart map,
/// following its `RecognizeResult.data` (`Page`) shape:
/// `{'blocks': [{'paragraphs': [{'lines': [{'text', 'confidence',
/// 'rowAttributes': {'rowHeight'}, 'bbox': {'x0', 'y0', 'x1', 'y1'}},
/// ...]}, ...]}, ...]}`.
abstract class TesseractEngine {
  /// [blocks] is always `true` in production; [TesseractTextRecognizer]
  /// requests block/paragraph/line geometry on every call. It's a parameter
  /// rather than hardcoded here so a fake engine can assert it was
  /// requested.
  Future<Map<String, Object?>> recognize(
    Uint8List bytes, {
    required bool blocks,
  });

  /// Releases the underlying Tesseract.js worker.
  Future<void> terminate();
}

/// Tesseract.js is loaded globally via a `<script>` tag in `index.html`,
/// pinned to this exact release. `workerPath`/`corePath`/`langPath` below
/// are pinned to the same release so all four never drift apart.
const _tesseractVersion = '7.0.0';
const _workerPath =
    'https://cdn.jsdelivr.net/npm/tesseract.js@$_tesseractVersion/dist/worker.min.js';
const _corePath =
    'https://cdn.jsdelivr.net/npm/tesseract.js-core@$_tesseractVersion';
const _langPath = 'https://tessdata.projectnaptha.com/4.0.0_fast';

/// Runs the real Tesseract.js library (loaded as the `Tesseract` global).
class PluginTesseractEngine implements TesseractEngine {
  JSObject? _worker;

  @override
  Future<Map<String, Object?>> recognize(
    Uint8List bytes, {
    required bool blocks,
  }) async {
    final worker = _worker ??= await _createWorker();
    final output = JSObject()..['blocks'] = blocks.toJS;
    final promise = worker.callMethod<JSPromise<JSAny>>(
      'recognize'.toJS,
      _toBlob(bytes),
      JSObject(),
      output,
    );
    final result = await promise.toDart;
    final data = (result as JSObject)['data'];
    return Map<String, Object?>.from(data.dartify() as Map<Object?, Object?>);
  }

  Future<JSObject> _createWorker() async {
    final tesseract = globalContext.getProperty<JSObject>('Tesseract'.toJS);
    final options = JSObject()
      ..['corePath'] = _corePath.toJS
      ..['langPath'] = _langPath.toJS
      ..['workerPath'] = _workerPath.toJS;
    final promise = tesseract.callMethod<JSPromise<JSAny>>(
      'createWorker'.toJS,
      'eng'.toJS,
      1.toJS,
      options,
    );
    return (await promise.toDart) as JSObject;
  }

  @override
  Future<void> terminate() async {
    final worker = _worker;
    if (worker == null) return;
    _worker = null;
    final promise = worker.callMethod<JSPromise<JSAny>>('terminate'.toJS);
    await promise.toDart;
  }
}

web.Blob _toBlob(Uint8List bytes) {
  final parts = <web.BlobPart>[bytes.toJS];
  return web.Blob(parts.toJS, web.BlobPropertyBag(type: 'image/png'));
}

/// Wraps Tesseract.js for web.
class TesseractTextRecognizer implements TextRecognizer {
  TesseractTextRecognizer({TesseractEngine? engine})
    : _engine = engine ?? PluginTesseractEngine();

  final TesseractEngine _engine;

  @override
  Future<RecognizedText> recognize(RecognizableImage image) async {
    final Map<String, Object?> data;
    try {
      data = await _engine.recognize(image.bytes, blocks: true);
    } catch (e) {
      throw TextRecognitionFailure('Tesseract: $e');
    }
    return _toRecognizedText(data);
  }

  @override
  Future<void> dispose() => _engine.terminate();
}

RecognizedText _toRecognizedText(Map<String, Object?> data) {
  final blocks = data['blocks'] as List<Object?>? ?? const [];
  final lines = <RecognizedLine>[
    for (final block in blocks)
      for (final paragraph
          in (block as Map<String, Object?>)['paragraphs'] as List<Object?>? ??
              const [])
        for (final line
            in (paragraph as Map<String, Object?>)['lines'] as List<Object?>? ??
                const [])
          _toRecognizedLine(line as Map<String, Object?>),
  ];
  return RecognizedText(lines);
}

RecognizedLine _toRecognizedLine(Map<String, Object?> line) {
  final rowAttributes = line['rowAttributes'] as Map<String, Object?>?;
  final bbox = line['bbox'] as Map<String, Object?>?;
  final rowHeight = (rowAttributes?['rowHeight'] as num?)?.toDouble();
  final bboxHeight = bbox == null
      ? null
      : (bbox['y1'] as num).toDouble() - (bbox['y0'] as num).toDouble();
  final height = rowHeight ?? bboxHeight;

  RecognizedLineBounds? bounds;
  if (bbox != null) {
    final top = (bbox['y0'] as num).toDouble();
    bounds = RecognizedLineBounds(
      top: top,
      bottom: height != null ? top + height : (bbox['y1'] as num).toDouble(),
      left: (bbox['x0'] as num).toDouble(),
      right: (bbox['x1'] as num).toDouble(),
    );
  }

  final rawConfidence = line['confidence'] as num?;
  return RecognizedLine(
    text: line['text'] as String,
    bounds: bounds,
    confidence: rawConfidence == null ? null : rawConfidence.toDouble() / 100,
  );
}
