import 'dart:typed_data';

import 'package:domain/domain.dart' show Decimal;
import 'package:ocr/ocr.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';

import 'package:spendwise/ocr/amount_extraction.dart';
import 'package:spendwise/ocr/date_extraction.dart';
import 'package:spendwise/ocr/name_extraction.dart';
import 'package:spendwise/ocr/receipt_recognizer_selection.dart';

/// Which action the user tapped, and which permission/picker source that
/// implies.
enum ReceiptScanSource { camera, gallery }

extension on ReceiptScanSource {
  Permission get permission =>
      this == ReceiptScanSource.camera ? Permission.camera : Permission.photos;

  ImageSource get pickerSource => this == ReceiptScanSource.camera
      ? ImageSource.camera
      : ImageSource.gallery;
}

/// Why a scan attempt produced no prefill, so the caller can decide whether
/// to show a message.
enum ReceiptScanStop {
  /// The user denied the camera/photo-library permission.
  permissionDenied,

  /// The user backed out of the camera/picker without choosing an image.
  cancelled,
}

/// Extracted fields ready to prefill the entry form. A field left unresolved
/// stays null rather than guessed, except [date], which defaults to today.
typedef ScanResultHandler =
    void Function({String? name, Decimal? amount, required DateTime date});

/// Returns early and calls [onStop] on a denied permission or a cancelled
/// picker. Any other failure still calls [onExtracted] with whatever fields
/// could be read. [preCapturedBytes], when given, skips straight to
/// recognizing those bytes.
Future<void> runReceiptScan({
  required ReceiptScanSource source,
  required ScanResultHandler onExtracted,
  Uint8List? preCapturedBytes,
  void Function(ReceiptScanStop stop)? onStop,
}) async {
  final bytes = preCapturedBytes ?? await _pickImage(source, onStop);
  if (bytes == null) return;

  final recognized = await _recognize(bytes);
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

Future<RecognizedText> _recognize(Uint8List bytes) async {
  final recognizer = selectRecognizer();
  if (recognizer == null) return RecognizedText(const []);

  try {
    return await recognizer.recognize(RecognizableImage(bytes));
  } on TextRecognitionFailure {
    // A corrupt file behaves the same as an image with no text.
    return RecognizedText(const []);
  } finally {
    await recognizer.dispose();
  }
}
