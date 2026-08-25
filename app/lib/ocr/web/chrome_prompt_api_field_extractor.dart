import 'dart:js_interop';

import 'package:decimal/decimal.dart';

import '../field_extractor.dart';
import '../receipt_prompt_field_extractor.dart';
import 'chrome_prompt_api_interop.dart';

/// One string in, one string out - the seam `ChromePromptApiFieldExtractor`
/// calls instead of touching `dart:js_interop` directly, so a test can fake
/// the browser call without a real `LanguageModel` global.
abstract class PromptApiEngine {
  Future<String> prompt(String input);
}

/// Runs each prompt through a real Chrome `LanguageModel` session, reusing
/// one session across calls until [dispose] destroys it.
class LanguageModelEngine implements PromptApiEngine {
  // Chrome's session, unlike Android's ML Kit client, is not documented as
  // unsafe to reuse, and creating one triggers Chrome's download-eligibility
  // and user-activation checks - overhead not worth repeating per field.
  Future<JSLanguageModelSession>? _sessionFuture;

  @override
  Future<String> prompt(String input) async {
    // Holding the pending create() call, not just its result, means two
    // concurrent callers (extractName and extractAmount run together) share
    // one session instead of each starting their own.
    final session = await (_sessionFuture ??= JSLanguageModel.create().toDart);
    final response = await session.prompt(input.toJS).toDart;
    return response.toDart;
  }

  Future<void> dispose() async {
    final sessionFuture = _sessionFuture;
    _sessionFuture = null;
    (await sessionFuture)?.destroy();
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

  ReceiptPromptFieldExtractor get _inner => ReceiptPromptFieldExtractor(
    runPrompt: _engine.prompt,
    engineName: 'Chrome Prompt API',
  );

  @override
  Future<String?> extractName(String readingOrderText) =>
      _inner.extractName(readingOrderText);

  @override
  Future<Decimal?> extractAmount(String readingOrderText) =>
      _inner.extractAmount(readingOrderText);

  @override
  Future<void> dispose() async {
    final engine = _engine;
    if (engine is LanguageModelEngine) await engine.dispose();
  }
}
