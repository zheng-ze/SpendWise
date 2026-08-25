import 'package:flutter/foundation.dart';

// Native builds cannot import the web selector and web builds cannot import
// the native one, because each pulls libraries the other platform has no
// compiler support for. This picks the right one at build time.
import 'web/chrome_prompt_api_selector_native.dart'
    if (dart.library.js_interop) 'web/chrome_prompt_api_selector_web.dart'
    as prompt_api;
import 'android/nano_channel.dart';
import 'android/nano_field_extractor.dart';
import 'field_extractor.dart';
import 'ios/foundation_models_field_extractor.dart';

/// Picks the field extractor for the current platform, or null if none is
/// eligible right now. Each platform's own eligibility check and engine are
/// swapped in independently, so overriding one for a test never has to fake
/// the other two:
/// - [isNanoEligible] fixes Android's AICore/Gemini Nano check.
/// - [isFoundationModelsEligible] fixes iOS's Foundation Models check.
/// - [isPromptApiEligible] fixes web's Chrome Prompt API check.
Future<FieldExtractor?> selectFieldExtractor({
  bool? isWeb,
  bool? isIOS,
  Future<bool> Function()? isNanoEligible,
  Future<bool> Function()? isFoundationModelsEligible,
  Future<bool> Function()? isPromptApiEligible,
}) async {
  // Web is checked first because dart:js_interop, which the web branch needs,
  // has no equivalent on the other platforms.
  if (isWeb ?? kIsWeb) {
    return prompt_api.selectChromePromptApiExtractor(
      isPromptApiEligible: isPromptApiEligible,
    );
  }

  if (isIOS ?? defaultTargetPlatform == TargetPlatform.iOS) {
    final eligible =
        await (isFoundationModelsEligible ?? isFoundationModelsAvailable)();
    return eligible ? FoundationModelsFieldExtractor() : null;
  }

  final eligible = await (isNanoEligible ?? _isNanoAvailable)();
  return eligible ? NanoFieldExtractor() : null;
}

Future<bool> _isNanoAvailable() async {
  final status = await NanoChannel().checkFeatureStatus();
  // Downloadable/downloading means Nano isn't ready to run yet - treated the
  // same as unavailable, since triggering and awaiting that download isn't built.
  return status == NanoFeatureStatus.available;
}
