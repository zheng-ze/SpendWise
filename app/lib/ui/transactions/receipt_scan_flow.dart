import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ocr/ocr.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:spendwise/ocr/date_extraction.dart';
import 'package:spendwise/ocr/field_extraction_failure.dart';
import 'package:spendwise/ocr/field_extractor.dart';
import 'package:spendwise/ocr/field_extractor_selection.dart';
import 'package:spendwise/ocr/line_rows.dart';
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
///
/// [preCapturedBytes], when given, skips the permission check and the
/// picker entirely and recognizes those bytes directly - the caller is
/// expected to have already captured the image itself (a native document
/// scanner, or web's manual crop screen), including handling its own
/// cancel case before ever calling this function.
Future<void> runReceiptScan({
  required ReceiptScanSource source,
  required EntryFormController controller,
  Uint8List? preCapturedBytes,
  void Function(ReceiptScanStop stop)? onStop,
}) async {
  final bytes = preCapturedBytes ?? await _pickImage(source, onStop);
  if (bytes == null) return;

  final recognized = await _recognize(bytes);
  await applyExtractedFields(recognized, controller);
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

/// Fills [controller] from [recognized]'s text: date always (heuristic,
/// defaults to today), name/amount from whatever [selectFieldExtractor]
/// returns and can extract.
@visibleForTesting
Future<void> applyExtractedFields(
  RecognizedText recognized,
  EntryFormController controller, {
  Future<FieldExtractor?> Function()? selectExtractor,
}) async {
  final fields = await _extractFields(
    recognized,
    selectExtractor ?? selectFieldExtractor,
  );
  controller.applyScanResult(
    name: fields.name,
    amount: fields.amount,
    date: extractDate(recognized),
  );
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

// Bundled so a caller with nothing to report can hand back one value
// instead of juggling name and amount separately.
class _ExtractedFields {
  const _ExtractedFields({this.name, this.amount});

  final String? name;
  final Decimal? amount;

  static const none = _ExtractedFields();
}

// No extractor and a throwing extractor both resolve to blank fields here,
// same as the recognition failure above.
Future<_ExtractedFields> _extractFields(
  RecognizedText recognized,
  Future<FieldExtractor?> Function() selectExtractor,
) async {
  final extractor = await selectExtractor();
  if (extractor == null) return _ExtractedFields.none;

  try {
    final text = toReadingOrderText(recognized.lines);
    final nameFuture = extractor.extractName(text);
    final amountFuture = extractor.extractAmount(text);
    return _ExtractedFields(name: await nameFuture, amount: await amountFuture);
  } on FieldExtractionFailure {
    return _ExtractedFields.none;
  } finally {
    await extractor.dispose();
  }
}
