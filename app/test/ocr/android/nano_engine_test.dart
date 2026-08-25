import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ocr/android/nano_engine.dart';
import 'package:spendwise/ocr/android/nano_field_extractor.dart';
import 'package:spendwise/ocr/field_extraction_failure.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('spendwise/nano_field_extractor');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('ChannelNanoEngine round-trips a successful response', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => 'Kopi Tiam',
    );

    expect(await ChannelNanoEngine().runInference('name?'), 'Kopi Tiam');
  });

  test(
    'a PlatformException from the channel becomes a FieldExtractionFailure '
    'at the NanoFieldExtractor seam',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'runInference', message: 'AICore crashed');
      });

      final extractor = NanoFieldExtractor(engine: ChannelNanoEngine());

      expect(
        () => extractor.extractName('Kopi Tiam\nTOTAL 9.50'),
        throwsA(isA<FieldExtractionFailure>()),
      );
    },
  );
}
