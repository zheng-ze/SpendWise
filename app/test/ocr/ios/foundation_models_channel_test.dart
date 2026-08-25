import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ocr/ios/foundation_models_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('spendwise/foundation_models_field_extractor');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  group('checkFeatureStatus', () {
    test(
      'maps the native int response onto FoundationModelsFeatureStatus',
      () async {
        messenger.setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'checkFeatureStatus');
          return 1;
        });

        expect(
          await FoundationModelsChannel().checkFeatureStatus(),
          FoundationModelsFeatureStatus.available,
        );
      },
    );

    test('treats a null native response as unavailable', () async {
      messenger.setMockMethodCallHandler(channel, (call) async => null);

      expect(
        await FoundationModelsChannel().checkFeatureStatus(),
        FoundationModelsFeatureStatus.unavailable,
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

      expect(
        await FoundationModelsChannel().runInference('hello'),
        'Kopi Tiam',
      );
    });

    test('propagates a PlatformException from the native side', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'runInference', message: 'boom');
      });

      expect(
        () => FoundationModelsChannel().runInference('hello'),
        throwsA(isA<PlatformException>()),
      );
    });

    test(
      'throws a PlatformException when the native side returns null',
      () async {
        messenger.setMockMethodCallHandler(channel, (call) async => null);

        expect(
          () => FoundationModelsChannel().runInference('hello'),
          throwsA(isA<PlatformException>()),
        );
      },
    );
  });
}
