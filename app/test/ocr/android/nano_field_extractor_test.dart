import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ocr/android/nano_engine.dart';
import 'package:spendwise/ocr/android/nano_field_extractor.dart';
import 'package:spendwise/ocr/field_extraction_failure.dart';

void main() {
  group('extractName', () {
    test('returns the trimmed model response', () async {
      final extractor = NanoFieldExtractor(
        engine: _FakeNanoEngine(response: '  Kopi Tiam  '),
      );

      expect(await extractor.extractName('Kopi Tiam\nTOTAL 9.50'), 'Kopi Tiam');
    });

    test(
      'returns null when the model responds with its none-found token',
      () async {
        final extractor = NanoFieldExtractor(
          engine: _FakeNanoEngine(response: 'NONE'),
        );

        expect(await extractor.extractName('No name here'), isNull);
      },
    );

    test('throws FieldExtractionFailure when the engine call throws', () async {
      final extractor = NanoFieldExtractor(engine: _ThrowingNanoEngine());

      expect(
        () => extractor.extractName('Kopi Tiam'),
        throwsA(isA<FieldExtractionFailure>()),
      );
    });
  });

  group('extractAmount', () {
    test('parses a currency-shaped model response into Decimal', () async {
      final extractor = NanoFieldExtractor(
        engine: _FakeNanoEngine(response: r'$9.50'),
      );

      expect(
        await extractor.extractAmount('SUBTOTAL 8.00\nTOTAL 9.50'),
        Decimal.parse('9.50'),
      );
    });

    test(
      'returns null when the model responds with its none-found token',
      () async {
        final extractor = NanoFieldExtractor(
          engine: _FakeNanoEngine(response: 'NONE'),
        );

        expect(await extractor.extractAmount('no total here'), isNull);
      },
    );

    test(
      'returns null when the model response is not a parseable number',
      () async {
        final extractor = NanoFieldExtractor(
          engine: _FakeNanoEngine(response: 'not a number'),
        );

        expect(await extractor.extractAmount('garbled receipt'), isNull);
      },
    );

    test('throws FieldExtractionFailure when the engine call throws', () async {
      final extractor = NanoFieldExtractor(engine: _ThrowingNanoEngine());

      expect(
        () => extractor.extractAmount('TOTAL 9.50'),
        throwsA(isA<FieldExtractionFailure>()),
      );
    });
  });

  test('dispose does not throw', () async {
    final extractor = NanoFieldExtractor(
      engine: _FakeNanoEngine(response: 'x'),
    );

    await expectLater(extractor.dispose(), completes);
  });
}

class _FakeNanoEngine implements NanoEngine {
  _FakeNanoEngine({required this.response});

  final String response;
  final prompts = <String>[];

  @override
  Future<String> runInference(String prompt) async {
    prompts.add(prompt);
    return response;
  }
}

class _ThrowingNanoEngine implements NanoEngine {
  @override
  Future<String> runInference(String prompt) {
    throw StateError('boom');
  }
}
