import 'package:decimal/decimal.dart';

import 'field_extraction_failure.dart';
import 'field_extractor.dart';

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

/// Runs one prompt and returns the model's raw text response. Each platform
/// wraps its own engine call in this shape.
typedef PromptRunner = Future<String> Function(String prompt);

/// Shares the receipt name/amount prompts, response parsing, and failure
/// wrapping across every platform's [FieldExtractor]. Each platform supplies
/// [runPrompt] (its engine call) and [engineName] (for the wrapped failure's
/// message) and gets both [FieldExtractor] methods for free.
class ReceiptPromptFieldExtractor implements FieldExtractor {
  ReceiptPromptFieldExtractor({
    required this.runPrompt,
    required this.engineName,
  });

  final PromptRunner runPrompt;
  final String engineName;

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

  Future<String> _runInference(String prompt) async {
    try {
      return await runPrompt(prompt);
    } catch (e) {
      throw FieldExtractionFailure('$engineName: $e');
    }
  }

  @override
  Future<void> dispose() async {}
}
