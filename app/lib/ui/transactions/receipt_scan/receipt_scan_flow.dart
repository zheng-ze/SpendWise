import 'dart:typed_data';

import 'package:domain/domain.dart' show Decimal;
import 'package:ocr/ocr.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';

import 'package:spendwise/ocr/amount_extraction.dart';
import 'package:spendwise/ocr/date_extraction.dart';
import 'package:spendwise/ocr/name_extraction.dart';
import 'package:spendwise/ocr/receipt_recognizer_selection.dart';

TextRecognizer? defaultRecognizer() => selectRecognizer();

enum ReceiptScanSource { camera, gallery }

extension on ReceiptScanSource {
  Permission get permission =>
      this == ReceiptScanSource.camera ? Permission.camera : Permission.photos;

  ImageSource get pickerSource => this == ReceiptScanSource.camera
      ? ImageSource.camera
      : ImageSource.gallery;
}

enum ReceiptScanStop { permissionDenied, cancelled }

typedef ScanResultHandler = void Function({
  String? name,
  Decimal? amount,
  required DateTime date,
});

typedef RecognizerFactory = TextRecognizer? Function();

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
  final granted = await _requestPermission(source.permission);
  if (!granted) {
    onStop?.call(ReceiptScanStop.permissionDenied);
    return null;
  }

  final picked = await ImagePicker().pickImage(source: source.pickerSource);
  if (picked == null) {
    onStop?.call(ReceiptScanStop.cancelled);
    return null;
  }

  return picked.readAsBytes();
}

Future<bool> _requestPermission(Permission permission) async {
  final status = await permission.request();
  return status.isGranted || status.isLimited;
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
