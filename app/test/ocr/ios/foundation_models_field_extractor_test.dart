import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ocr/field_extraction_failure.dart';
import 'package:spendwise/ocr/ios/foundation_models_engine.dart';
import 'package:spendwise/ocr/ios/foundation_models_field_extractor.dart';

void main() {
  group('extractName', () {
    test('returns the trimmed model response', () async {
      final extractor = FoundationModelsFieldExtractor(
        engine: _FakeFoundationModelsEngine(response: '  Kopi Tiam  '),
      );

      expect(await extractor.extractName('Kopi Tiam\nTOTAL 9.50'), 'Kopi Tiam');
    });

    test(
      'returns null when the model responds with its none-found token',
      () async {
        final extractor = FoundationModelsFieldExtractor(
          engine: _FakeFoundationModelsEngine(response: 'NONE'),
        );

        expect(await extractor.extractName('No name here'), isNull);
      },
    );

    test('throws FieldExtractionFailure when the engine call throws', () async {
      final extractor = FoundationModelsFieldExtractor(
        engine: _ThrowingFoundationModelsEngine(),
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
        engine: _FakeFoundationModelsEngine(response: r'$9.50'),
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
          engine: _FakeFoundationModelsEngine(response: 'NONE'),
        );

        expect(await extractor.extractAmount('no total here'), isNull);
      },
    );

    test(
      'returns null when the model response is not a parseable number',
      () async {
        final extractor = FoundationModelsFieldExtractor(
          engine: _FakeFoundationModelsEngine(response: 'not a number'),
        );

        expect(await extractor.extractAmount('garbled receipt'), isNull);
      },
    );

    test('throws FieldExtractionFailure when the engine call throws', () async {
      final extractor = FoundationModelsFieldExtractor(
        engine: _ThrowingFoundationModelsEngine(),
      );

      expect(
        () => extractor.extractAmount('TOTAL 9.50'),
        throwsA(isA<FieldExtractionFailure>()),
      );
    });
  });

  test('dispose does not throw', () async {
    final extractor = FoundationModelsFieldExtractor(
      engine: _FakeFoundationModelsEngine(response: 'x'),
    );

    await expectLater(extractor.dispose(), completes);
  });
}

class _FakeFoundationModelsEngine implements FoundationModelsEngine {
  _FakeFoundationModelsEngine({required this.response});

  final String response;
  final prompts = <String>[];

  @override
  Future<String> runInference(String prompt) async {
    prompts.add(prompt);
    return response;
  }
}

class _ThrowingFoundationModelsEngine implements FoundationModelsEngine {
  @override
  Future<String> runInference(String prompt) {
    throw StateError('boom');
  }
}
