import 'dart:typed_data';

import 'package:domain/domain.dart' show Decimal;
import 'package:ocr/ocr.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:image_picker/image_picker.dart';

import 'package:spendwise/ocr/amount_extraction.dart';
import 'package:spendwise/ocr/date_extraction.dart';
import 'package:spendwise/ocr/name_extraction.dart';
import 'package:spendwise/ocr/receipt_recognizer_selection.dart';

TextRecognizer? defaultRecognizer() => selectRecognizer();

// MARK: - ReceiptScanSource
enum ReceiptScanSource { camera, gallery }

// MARK: - ReceiptScanSourceMapping
extension ReceiptScanSourceMapping on ReceiptScanSource {
  ImageSource get pickerSource => this == ReceiptScanSource.camera
      ? ImageSource.camera
      : ImageSource.gallery;
}

// MARK: - ReceiptScanStop
enum ReceiptScanStop { permissionDenied, cancelled }

// MARK: - Scan Handlers
typedef ScanResultHandler = void Function({
  String? name,
  Decimal? amount,
  required DateTime date,
});

typedef RecognizerFactory = TextRecognizer? Function();

// MARK: - Constants
const _accessDeniedCodes = {
  'camera_access_denied',
  'camera_access_restricted',
  'photo_access_denied',
  'photo_access_restricted',
};

// MARK: - Helpers
Future<void> runReceiptScan({
  required ReceiptScanSource source,
  required ScanResultHandler onExtracted,
  Uint8List? preCapturedBytes,
  void Function(ReceiptScanStop stop)? onStop,
  RecognizerFactory recognizer = defaultRecognizer,
}) async {
  final bytes = preCapturedBytes ?? await _pickImage(source, onStop);
  if (bytes == null) return;

  final recognized = await _recognize(recognizer, bytes);
  onExtracted(
    name: extractName(recognized),
    amount: extractAmount(recognized),
    date: extractDate(recognized),
  );
}

Future<Uint8List?> _pickImage(
  ReceiptScanSource source,
  void Function(ReceiptScanStop stop)? onStop,
) async {
  final XFile? picked;
  try {
    picked = await ImagePicker().pickImage(source: source.pickerSource);
  } on PlatformException catch (error) {
    if (!_accessDeniedCodes.contains(error.code)) rethrow;
    onStop?.call(ReceiptScanStop.permissionDenied);
    return null;
  }

  if (picked == null) {
    onStop?.call(ReceiptScanStop.cancelled);
    return null;
  }

  return picked.readAsBytes();
}

Future<RecognizedText> _recognize(
  RecognizerFactory factory,
  Uint8List bytes,
) async {
  final recognizer = factory();
  if (recognizer == null) return RecognizedText(const []);

  try {
    return await recognizer.recognize(RecognizableImage(bytes));
  } on TextRecognitionFailure {
    return RecognizedText(const []);
  } finally {
    await recognizer.dispose();
  }
}
