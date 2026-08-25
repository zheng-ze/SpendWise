import '../field_extractor.dart';
import 'chrome_prompt_api_availability.dart';
import 'chrome_prompt_api_field_extractor.dart';

// This file is only ever compiled into a web build, so it's safe for it to
// import code that needs dart:js_interop, which no other platform has.

Future<FieldExtractor?> selectChromePromptApiExtractor({
  Future<bool> Function()? isPromptApiEligible,
}) async {
  final eligible = await (isPromptApiEligible ?? isChromePromptApiAvailable)();
  return eligible ? ChromePromptApiFieldExtractor() : null;
}
