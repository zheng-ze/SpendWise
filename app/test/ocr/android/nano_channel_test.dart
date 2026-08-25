import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ocr/android/nano_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('spendwise/nano_field_extractor');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  group('checkFeatureStatus', () {
    test('maps the native int response onto NanoFeatureStatus', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'checkFeatureStatus');
        return 3;
      });

      expect(
        await NanoChannel().checkFeatureStatus(),
        NanoFeatureStatus.available,
      );
    });
  });

  group('runInference', () {
    test('sends the prompt and returns the native text response', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'runInference');
        expect(call.arguments, {'prompt': 'hello'});
        return 'Kopi Tiam';
      });

      expect(await NanoChannel().runInference('hello'), 'Kopi Tiam');
    });

    test('propagates a PlatformException from the native side', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'runInference', message: 'boom');
      });

      expect(
        () => NanoChannel().runInference('hello'),
        throwsA(isA<PlatformException>()),
      );
    });
  });
}
