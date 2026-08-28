import 'package:domain/domain.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocr/ocr.dart';
import 'package:spendwise/ocr/amount_extraction.dart';
import 'package:spendwise/ocr/date_extraction.dart';
import 'package:spendwise/ocr/name_extraction.dart';
import 'package:spendwise/ui/transactions/receipt_scan_flow.dart';

RecognizedText _textOf(List<String> lines) {
  return RecognizedText([
    for (final text in lines)
      RecognizedLine(text: text, recognizedLanguages: const []),
  ]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const mlKitChannel = MethodChannel('google_mlkit_text_recognizer');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    messenger.setMockMethodCallHandler(mlKitChannel, (call) async {
      if (call.method == 'vision#startTextRecognizer') {
        return {'text': '', 'blocks': <Object?>[]};
      }
      return null;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(mlKitChannel, null);
  });

  // Regression: runReceiptScan previously called a nonexistent
  // FieldExtractor/_extractFields abstraction, which failed to compile and
  // blocked this whole test file (and every file that transitively imports
  // it) from loading.
  test(
    'runs recognition on preCapturedBytes without requesting permission or using the picker',
    () async {
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
    },
  );

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
