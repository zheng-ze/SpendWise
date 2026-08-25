import 'dart:js_interop';

import 'package:decimal/decimal.dart';

import '../field_extraction_failure.dart';
import '../field_extractor.dart';
import 'chrome_prompt_api_interop.dart';

// The model is told to answer with this exact token when a field isn't on
// the receipt, so "found nothing" is a string compare instead of another
// round of free-form-response parsing. Matches Android's prompt wording,
// since the extraction task is identical and only the engine differs.
const _noneFoundToken = 'NONE';

const _namePrompt =
    'You are reading the text of a store receipt, scanned line by line from '
    'top to bottom. Identify the name of the merchant or business that '
    'issued this receipt. Reply with only the merchant name, nothing else. '
    'If no merchant name is present, reply with exactly "$_noneFoundToken".\n\n'
    'Receipt text:\n';

// Amount needs explicit exclusion/priority guidance (issue #18's finding,
// carried over from Android's prompt): an unguided prompt confused
// "Cash"/"Change Due" lines with the real total.
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

/// One string in, one string out - the seam `ChromePromptApiFieldExtractor`
/// calls instead of touching `dart:js_interop` directly, so a test can fake
/// the browser call the same way `NanoEngine` lets `nano_field_extractor.dart`
/// fake Android's platform channel.
abstract class PromptApiEngine {
  Future<String> prompt(String input);
}

/// Runs each prompt through a real Chrome `LanguageModel` session, reusing
/// one session across calls until [dispose] destroys it.
class LanguageModelEngine implements PromptApiEngine {
  // Chrome's session, unlike Android's ML Kit client, is not documented as
  // unsafe to reuse, and creating one triggers Chrome's download-eligibility
  // and user-activation checks - overhead not worth repeating per field.
  JSLanguageModelSession? _session;

  @override
  Future<String> prompt(String input) async {
    final session = _session ??= await JSLanguageModel.create().toDart;
    final response = await session.prompt(input.toJS).toDart;
    return response.toDart;
  }

  Future<void> dispose() async {
    _session?.destroy();
    _session = null;
  }
}

/// Extracts receipt fields using Gemini Nano through Chrome's built-in
/// Prompt API (`LanguageModel`, Chrome 148+). Whether this can even be
/// constructed for the current browser is decided by
/// `field_extractor_selection.dart`, not here.
class ChromePromptApiFieldExtractor implements FieldExtractor {
  ChromePromptApiFieldExtractor({PromptApiEngine? engine})
    : _engine = engine ?? LanguageModelEngine();

  final PromptApiEngine _engine;

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
      return await _engine.prompt(prompt);
    } catch (e) {
      throw FieldExtractionFailure('Chrome Prompt API: $e');
    }
  }

  @override
  Future<void> dispose() async {
    final engine = _engine;
    if (engine is LanguageModelEngine) await engine.dispose();
  }
}
