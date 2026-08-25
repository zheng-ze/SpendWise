import 'package:decimal/decimal.dart';

import '../field_extraction_failure.dart';
import '../field_extractor.dart';
import 'nano_engine.dart';

// The model is told to answer with this exact token when a field isn't on
// the receipt, so "found nothing" is a string compare instead of another
// round of free-form-response parsing.
const _noneFoundToken = 'NONE';

const _namePrompt =
    'You are reading the text of a store receipt, scanned line by line from '
    'top to bottom. Identify the name of the merchant or business that '
    'issued this receipt. Reply with only the merchant name, nothing else. '
    'If no merchant name is present, reply with exactly "$_noneFoundToken".\n\n'
    'Receipt text:\n';

// Amount needs explicit exclusion/priority guidance (issue #18's finding):
// an unguided prompt confused "Cash"/"Change Due" lines with the real total.
const _amountPrompt =
    'You are reading the text of a store receipt, scanned line by line from '
    'top to bottom. Identify the final total amount the customer was '
    'charged. Prefer a line labeled "Total", "Grand Total", or "Amount Due". '
    'Ignore lines labeled "Subtotal", "Tax", "Cash", "Change Due", or '
    '"Tendered" - those are not the total. Reply with only the amount as a '
    'number, optionally with a currency symbol, nothing else. If no total '
    'amount is present, reply with exactly "$_noneFoundToken".\n\n'
    'Receipt text:\n';

final _currencyNumber = RegExp(
  r'\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?|\d+\.\d{1,2}',
);

/// Extracts receipt fields using Gemini Nano through Android's ML Kit GenAI
/// Prompt API (AICore-backed). Whether this can even be constructed for the
/// current device is decided by `field_extractor_selection.dart`, not here.
class NanoFieldExtractor implements FieldExtractor {
  NanoFieldExtractor({NanoEngine? engine})
    : _engine = engine ?? ChannelNanoEngine();

  final NanoEngine _engine;

  @override
  Future<String?> extractName(String readingOrderText) async {
    final response = await _runInference('$_namePrompt$readingOrderText');
    final trimmed = response.trim();
    return trimmed.isEmpty || trimmed == _noneFoundToken ? null : trimmed;
  }

  @override
  Future<Decimal?> extractAmount(String readingOrderText) async {
    final response = await _runInference('$_amountPrompt$readingOrderText');
    if (response.trim() == _noneFoundToken) return null;

    final match = _currencyNumber.firstMatch(response);
    if (match == null) return null;
    return Decimal.tryParse(match.group(0)!.replaceAll(',', ''));
  }

  // Fresh prompt per call, never shared across the name and amount calls -
  // nothing confirms reusing one session across calls is safe here.
  Future<String> _runInference(String prompt) async {
    try {
      return await _engine.runInference(prompt);
    } catch (e) {
      throw FieldExtractionFailure('Gemini Nano: $e');
    }
  }

  @override
  Future<void> dispose() async {}
}
