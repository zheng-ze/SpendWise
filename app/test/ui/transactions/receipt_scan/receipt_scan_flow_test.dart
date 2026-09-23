import 'package:domain/domain.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocr/ocr.dart';
import 'package:spendwise/ocr/amount_extraction.dart';
import 'package:spendwise/ocr/date_extraction.dart';
import 'package:spendwise/ocr/name_extraction.dart';
import 'package:spendwise/ui/transactions/receipt_scan/receipt_scan_flow.dart';

RecognizedText _textOf(List<String> lines) {
  return RecognizedText([
    for (final text in lines)
      RecognizedLine(text: text, recognizedLanguages: const []),
  ]);
}

class _InMemoryRecognizer implements TextRecognizer {
  _InMemoryRecognizer(this.text);

  final RecognizedText text;
  bool disposed = false;

  @override
  Future<void> dispose() async => disposed = true;

  @override
  Future<RecognizedText> recognize(RecognizableImage image) async => text;
}

DateTime _todayUtc() {
  final now = DateTime.now();
  return DateTime.utc(now.year, now.month, now.day);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const mlKitChannel = MethodChannel('spendwise/android_text_recognizer');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    messenger.setMockMethodCallHandler(mlKitChannel, (call) async {
      if (call.method == 'recognizeText') {
        return <Map<Object?, Object?>>[];
      }
      return null;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(mlKitChannel, null);
  });

  test('runs recognition through an injected recognizer instead of the ML Kit channel', () async {
    messenger.setMockMethodCallHandler(mlKitChannel, null);

    final recognized = _textOf(['Coffee Shop', 'Total \$12.50', '01/15/2026']);
    final recognizer = _InMemoryRecognizer(recognized);

    String? capturedName;
    Decimal? capturedAmount;
    DateTime? capturedDate;

    await runReceiptScan(
      source: ReceiptScanSource.camera,
      preCapturedBytes: Uint8List(0),
      recognizer: () => recognizer,
      onExtracted: ({name, amount, required date}) =>
          (capturedName = name, capturedAmount = amount, capturedDate = date),
    );

    expect(capturedName, 'Coffee Shop');
    expect(capturedAmount, Decimal.parse('12.50'));
    expect(capturedDate, DateTime.utc(2026, 1, 15));
    expect(recognizer.disposed, isTrue);
  });

  test('runs recognition on preCapturedBytes without requesting permission or using the picker', () async {
    ReceiptScanStop? stop;
    DateTime? capturedDate;

    await runReceiptScan(
      source: ReceiptScanSource.camera,
      preCapturedBytes: Uint8List(0),
      onExtracted: ({name, amount, required date}) => capturedDate = date,
      onStop: (value) => stop = value,
    );

    expect(stop, isNull);
    expect(capturedDate, isNotNull);
  });

  test('falls through to a null name, null amount and a defaulted date when the recognizer factory returns null', () async {
    String? capturedName;
    Decimal? capturedAmount;
    DateTime? capturedDate;

    await runReceiptScan(
      source: ReceiptScanSource.camera,
      preCapturedBytes: Uint8List(0),
      recognizer: () => null,
      onExtracted: ({name, amount, required date}) =>
          (capturedName = name, capturedAmount = amount, capturedDate = date),
    );

    expect(capturedName, isNull);
    expect(capturedAmount, isNull);
    expect(capturedDate, _todayUtc());
  });

  test('extracts name, amount and date from recognized receipt text', () {
    final recognized = _textOf(['Coffee Shop', 'Total \$12.50', '01/15/2026']);

    final name = extractName(recognized);
    final amount = extractAmount(recognized);
    final date = extractDate(recognized, now: DateTime.utc(2026, 1, 20));

    expect(name, isNotNull);
    expect(amount, Decimal.parse('12.50'));
    expect(date, DateTime.utc(2026, 1, 15));
  });
}
