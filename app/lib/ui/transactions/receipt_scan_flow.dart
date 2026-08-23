import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:ocr/ocr.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:spendwise/ocr/amount_extraction.dart';
import 'package:spendwise/ocr/date_extraction.dart';
import 'package:spendwise/ocr/name_extraction.dart';
import 'package:spendwise/ocr/receipt_recognizer_selection.dart';
import 'package:spendwise/ui/transactions/entry_form_controller.dart';

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

/// Returns early and calls [onStop] on a denied permission or a cancelled
/// picker. Any other failure still fills [controller] with what it can.
Future<void> runReceiptScan({
  required ReceiptScanSource source,
  required EntryFormController controller,
  void Function(ReceiptScanStop stop)? onStop,
}) async {
  final granted = await _requestPermission(source.permission);
  if (!granted) {
    onStop?.call(ReceiptScanStop.permissionDenied);
    return;
  }

  final picked = await ImagePicker().pickImage(source: source.pickerSource);
  if (picked == null) {
    onStop?.call(ReceiptScanStop.cancelled);
    return;
  }

  final bytes = await picked.readAsBytes();
  final recognized = await _recognize(bytes);
  _applyExtractedFields(recognized, controller);
}

Future<bool> _requestPermission(Permission permission) async {
  final status = await permission.request();
  return status.isGranted || status.isLimited;
}

// A recognition failure returns empty lines rather than throwing further, so
// a corrupt file behaves the same as an image with no text.
Future<RecognizedText> _recognize(Uint8List bytes) async {
  final recognizer = selectRecognizer();
  if (recognizer == null) return RecognizedText(const []);

  try {
    return await recognizer.recognize(RecognizableImage(bytes));
  } on TextRecognitionFailure {
    return RecognizedText(const []);
  } finally {
    await recognizer.dispose();
  }
}

void _applyExtractedFields(
  RecognizedText recognized,
  EntryFormController controller,
) {
  controller.applyScanResult(
    name: extractName(recognized),
    amount: extractAmount(recognized),
    date: extractDate(recognized),
  );
}
