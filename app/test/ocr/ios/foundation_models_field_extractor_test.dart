import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ocr/field_extraction_failure.dart';
import 'package:spendwise/ocr/ios/foundation_models_field_extractor.dart';

void main() {
  group('extractName', () {
    test('returns the trimmed model response', () async {
      final extractor = FoundationModelsFieldExtractor(
        runPrompt: _fakeRunPrompt(response: '  Kopi Tiam  '),
      );

      expect(await extractor.extractName('Kopi Tiam\nTOTAL 9.50'), 'Kopi Tiam');
    });

    test(
      'returns null when the model responds with its none-found token',
      () async {
        final extractor = FoundationModelsFieldExtractor(
          runPrompt: _fakeRunPrompt(response: 'NONE'),
        );

        expect(await extractor.extractName('No name here'), isNull);
      },
    );

    test('throws FieldExtractionFailure when the engine call throws', () async {
      final extractor = FoundationModelsFieldExtractor(
        runPrompt: _throwingRunPrompt,
      );

      expect(
        () => extractor.extractName('Kopi Tiam'),
        throwsA(isA<FieldExtractionFailure>()),
      );
    });
  });

  group('extractAmount', () {
    test('parses a currency-shaped model response into Decimal', () async {
      final extractor = FoundationModelsFieldExtractor(
        runPrompt: _fakeRunPrompt(response: r'$9.50'),
      );

      expect(
        await extractor.extractAmount('SUBTOTAL 8.00\nTOTAL 9.50'),
        Decimal.parse('9.50'),
      );
    });

    test(
      'returns null when the model responds with its none-found token',
      () async {
        final extractor = FoundationModelsFieldExtractor(
          runPrompt: _fakeRunPrompt(response: 'NONE'),
        );

        expect(await extractor.extractAmount('no total here'), isNull);
      },
    );

    test(
      'returns null when the model response is not a parseable number',
      () async {
        final extractor = FoundationModelsFieldExtractor(
          runPrompt: _fakeRunPrompt(response: 'not a number'),
        );

        expect(await extractor.extractAmount('garbled receipt'), isNull);
      },
    );

    test('throws FieldExtractionFailure when the engine call throws', () async {
      final extractor = FoundationModelsFieldExtractor(
        runPrompt: _throwingRunPrompt,
      );

      expect(
        () => extractor.extractAmount('TOTAL 9.50'),
        throwsA(isA<FieldExtractionFailure>()),
      );
    });
  });

  test('dispose does not throw', () async {
    final extractor = FoundationModelsFieldExtractor(
      runPrompt: _fakeRunPrompt(response: 'x'),
    );

    await expectLater(extractor.dispose(), completes);
  });
}

Future<String> Function(String) _fakeRunPrompt({required String response}) {
  return (prompt) async => response;
}

Future<String> _throwingRunPrompt(String prompt) {
  throw StateError('boom');
}
