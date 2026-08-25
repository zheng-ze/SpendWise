import 'package:decimal/decimal.dart';

import '../field_extractor.dart';
import '../receipt_prompt_field_extractor.dart';
import 'foundation_models_channel.dart';

/// Extracts receipt fields using Apple's Foundation Models framework
/// (Apple-Intelligence-eligible devices, iOS 26+). Whether this can even be
/// constructed for the current device is decided by
/// `field_extractor_selection.dart`, not here.
class FoundationModelsFieldExtractor implements FieldExtractor {
  FoundationModelsFieldExtractor({PromptRunner? runPrompt})
    : _inner = ReceiptPromptFieldExtractor(
        runPrompt: runPrompt ?? FoundationModelsChannel().runInference,
        engineName: 'Foundation Models',
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

/// Reports whether Apple's Foundation Models framework can run on this
/// device right now. Takes no arguments so it matches the
/// `Future<bool> Function()` shape `field_extractor_selection.dart`'s
/// Android eligibility check already uses, letting the same optional-
/// override pattern wire this in as a drop-in default.
Future<bool> isFoundationModelsAvailable() async {
  final status = await FoundationModelsChannel().checkFeatureStatus();
  return status == FoundationModelsFeatureStatus.available;
}
