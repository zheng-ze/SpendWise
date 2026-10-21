import 'dart:io';

import 'package:domain/domain.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocr/ocr.dart';
import 'package:spendwise/ui/transactions/receipt_scan/receipt_scan_flow.dart';

import '../../../support/image_picker_channel.dart';

const _deniedCode = 'camera_access_denied';
const _otherErrorCode = 'invalid_image';
const _pickedBytes = [1, 2, 3];

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

class _CapturingRecognizer implements TextRecognizer {
  List<int>? seenBytes;

  @override
  Future<void> dispose() async {}

  @override
  Future<RecognizedText> recognize(RecognizableImage image) async {
    seenBytes = image.bytes;
    return RecognizedText(const []);
  }
}

DateTime _todayUtc() {
  final now = DateTime.now();
  return DateTime.utc(now.year, now.month, now.day);
}

void _ignoreExtracted({
  String? name,
  Decimal? amount,
  required DateTime date,
}) {}

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

  group('image picker outcomes', () {
    test('camera permission denial stops as permissionDenied', () async {
      mockImagePickerResult(errorCode: _deniedCode);
      ReceiptScanStop? stop;
      var extractedCalls = 0;

      await runReceiptScan(
        source: ReceiptScanSource.camera,
        onExtracted: ({name, amount, required date}) => extractedCalls++,
        onStop: (value) => stop = value,
      );

      expect(stop, ReceiptScanStop.permissionDenied);
      expect(extractedCalls, 0);
    });

    test('a cancelled pick stops as cancelled', () async {
      mockImagePickerResult();
      ReceiptScanStop? stop;

      await runReceiptScan(
        source: ReceiptScanSource.gallery,
        onExtracted: _ignoreExtracted,
        onStop: (value) => stop = value,
      );

      expect(stop, ReceiptScanStop.cancelled);
    });

    test('any other platform error propagates unchanged', () async {
      mockImagePickerResult(errorCode: _otherErrorCode);
      ReceiptScanStop? stop;

      final scan = runReceiptScan(
        source: ReceiptScanSource.gallery,
        onExtracted: _ignoreExtracted,
        onStop: (value) => stop = value,
      );

      await expectLater(
        scan,
        throwsA(
          isA<PlatformException>().having(
            (error) => error.code,
            'code',
            _otherErrorCode,
          ),
        ),
      );
      expect(stop, isNull);
    });

    test('a picked image is recognized from its bytes', () async {
      final directory = Directory.systemTemp.createTempSync('picked_receipt');
      addTearDown(() => directory.deleteSync(recursive: true));
      final file = File('${directory.path}/receipt.jpg')
        ..writeAsBytesSync(_pickedBytes);
      mockImagePickerResult(path: file.path);
      final recognizer = _CapturingRecognizer();
      ReceiptScanStop? stop;
      DateTime? capturedDate;

      await runReceiptScan(
        source: ReceiptScanSource.gallery,
        recognizer: () => recognizer,
        onExtracted: ({name, amount, required date}) => capturedDate = date,
        onStop: (value) => stop = value,
      );

      expect(stop, isNull);
      expect(capturedDate, isNotNull);
      expect(recognizer.seenBytes, _pickedBytes);
    });
  });
}
