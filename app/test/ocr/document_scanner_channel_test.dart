import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ocr/document_scanner_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('spendwise/document_scanner');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  group('scanDocument', () {
    test('returns the native side\'s JPEG bytes', () async {
      final bytes = Uint8List.fromList([1, 2, 3]);
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'scanDocument');
        return bytes;
      });

      expect(
        await DocumentScannerChannel('spendwise/document_scanner')
            .scanDocument(),
        bytes,
      );
    });

    test('returns null when the user cancels the scan', () async {
      messenger.setMockMethodCallHandler(channel, (call) async => null);

      expect(
        await DocumentScannerChannel('spendwise/document_scanner')
            .scanDocument(),
        isNull,
      );
    });

    test('propagates a PlatformException from the native side', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'scanDocument', message: 'boom');
      });

      expect(
        () =>
            DocumentScannerChannel('spendwise/document_scanner').scanDocument(),
        throwsA(isA<PlatformException>()),
      );
    });
  });

  group('isAvailable', () {
    test('returns true when the native side reports available', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'isAvailable');
        return true;
      });

      expect(
        await DocumentScannerChannel('spendwise/document_scanner')
            .isAvailable(),
        isTrue,
      );
    });

    test('returns false when the native side reports unavailable', () async {
      messenger.setMockMethodCallHandler(channel, (call) async => false);

      expect(
        await DocumentScannerChannel('spendwise/document_scanner')
            .isAvailable(),
        isFalse,
      );
    });

    test('returns false when the native side returns null', () async {
      messenger.setMockMethodCallHandler(channel, (call) async => null);

      expect(
        await DocumentScannerChannel('spendwise/document_scanner')
            .isAvailable(),
        isFalse,
      );
    });
  });
}
