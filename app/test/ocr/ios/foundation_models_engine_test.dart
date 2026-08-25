import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ocr/field_extraction_failure.dart';
import 'package:spendwise/ocr/ios/foundation_models_field_extractor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('spendwise/foundation_models_field_extractor');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('a PlatformException from the channel becomes a FieldExtractionFailure '
      'at the FoundationModelsFieldExtractor seam', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(
        code: 'runInference',
        message: 'model unavailable mid-call',
      );
    });

    final extractor = FoundationModelsFieldExtractor();

    expect(
      () => extractor.extractName('Kopi Tiam\nTOTAL 9.50'),
      throwsA(isA<FieldExtractionFailure>()),
    );
  });

  group('isFoundationModelsAvailable', () {
    test('returns true when the channel reports available', () async {
      messenger.setMockMethodCallHandler(channel, (call) async => 1);

      expect(await isFoundationModelsAvailable(), isTrue);
    });

    test('returns false when the channel reports unavailable', () async {
      messenger.setMockMethodCallHandler(channel, (call) async => 0);

      expect(await isFoundationModelsAvailable(), isFalse);
    });
  });
}
