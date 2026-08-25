import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ocr/field_extraction_failure.dart';
import 'package:spendwise/ocr/web/chrome_prompt_api_field_extractor.dart';

void main() {
  group('extractName', () {
    test('returns the trimmed model response', () async {
      final extractor = ChromePromptApiFieldExtractor(
        engine: _FakePromptApiEngine(response: '  Kopi Tiam  '),
      );

      expect(await extractor.extractName('Kopi Tiam\nTOTAL 9.50'), 'Kopi Tiam');
    });

    test(
      'returns null when the model responds with its none-found token',
      () async {
        final extractor = ChromePromptApiFieldExtractor(
          engine: _FakePromptApiEngine(response: 'NONE'),
        );

        expect(await extractor.extractName('No name here'), isNull);
      },
    );

    test('throws FieldExtractionFailure when the engine call throws', () async {
      final extractor = ChromePromptApiFieldExtractor(
        engine: _ThrowingPromptApiEngine(),
      );

      expect(
        () => extractor.extractName('Kopi Tiam'),
        throwsA(isA<FieldExtractionFailure>()),
      );
    });
  });

  group('extractAmount', () {
    test('parses a currency-shaped model response into Decimal', () async {
      final extractor = ChromePromptApiFieldExtractor(
        engine: _FakePromptApiEngine(response: r'$9.50'),
      );

      expect(
        await extractor.extractAmount('SUBTOTAL 8.00\nTOTAL 9.50'),
        Decimal.parse('9.50'),
      );
    });

    test(
      'returns null when the model responds with its none-found token',
      () async {
        final extractor = ChromePromptApiFieldExtractor(
          engine: _FakePromptApiEngine(response: 'NONE'),
        );

        expect(await extractor.extractAmount('no total here'), isNull);
      },
    );

    test(
      'returns null when the model response is not a parseable number',
      () async {
        final extractor = ChromePromptApiFieldExtractor(
          engine: _FakePromptApiEngine(response: 'not a number'),
        );

        expect(await extractor.extractAmount('garbled receipt'), isNull);
      },
    );

    test('throws FieldExtractionFailure when the engine call throws', () async {
      final extractor = ChromePromptApiFieldExtractor(
        engine: _ThrowingPromptApiEngine(),
      );

      expect(
        () => extractor.extractAmount('TOTAL 9.50'),
        throwsA(isA<FieldExtractionFailure>()),
      );
    });
  });

  test('reuses one engine across the name and amount calls', () async {
    final engine = _FakePromptApiEngine(response: 'Kopi Tiam');
    final extractor = ChromePromptApiFieldExtractor(engine: engine);

    await extractor.extractName('Kopi Tiam\nTOTAL 9.50');
    await extractor.extractAmount('Kopi Tiam\nTOTAL 9.50');

    expect(engine.prompts, hasLength(2));
  });

  test('dispose does not throw', () async {
    final extractor = ChromePromptApiFieldExtractor(
      engine: _FakePromptApiEngine(response: 'x'),
    );

    await expectLater(extractor.dispose(), completes);
  });
}

class _FakePromptApiEngine implements PromptApiEngine {
  _FakePromptApiEngine({required this.response});

  final String response;
  final prompts = <String>[];

  @override
  Future<String> prompt(String input) async {
    prompts.add(input);
    return response;
  }
}

class _ThrowingPromptApiEngine implements PromptApiEngine {
  @override
  Future<String> prompt(String input) {
    throw StateError('boom');
  }
}
