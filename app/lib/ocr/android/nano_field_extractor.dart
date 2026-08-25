import 'package:decimal/decimal.dart';

import '../field_extractor.dart';
import '../receipt_prompt_field_extractor.dart';
import 'nano_channel.dart';

/// Extracts receipt fields using Gemini Nano through Android's ML Kit GenAI
/// Prompt API (AICore-backed). Whether this can even be constructed for the
/// current device is decided by `field_extractor_selection.dart`, not here.
class NanoFieldExtractor implements FieldExtractor {
  NanoFieldExtractor({PromptRunner? runPrompt})
    : _inner = ReceiptPromptFieldExtractor(
        runPrompt: runPrompt ?? NanoChannel().runInference,
        engineName: 'Gemini Nano',
      );

  final ReceiptPromptFieldExtractor _inner;

  @override
  Future<String?> extractName(String readingOrderText) =>
      _inner.extractName(readingOrderText);

  @override
  Future<Decimal?> extractAmount(String readingOrderText) =>
      _inner.extractAmount(readingOrderText);

  @override
  Future<void> dispose() => _inner.dispose();
}
