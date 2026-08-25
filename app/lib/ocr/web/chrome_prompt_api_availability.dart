import 'dart:js_interop';

import 'package:flutter/foundation.dart';

import 'chrome_prompt_api_interop.dart';

/// Readiness states Chrome's `LanguageModel.availability()` reports, mirrored
/// verbatim from the Prompt API spec's four strings. The presence of the
/// `LanguageModel` global alone does not mean this: a browser can declare
/// the API before the Gemini Nano model itself has been downloaded for this
/// origin, which is exactly what [downloadable] and [downloading] cover.
enum PromptApiAvailability { unavailable, downloadable, downloading, available }

/// True when the current browser is Chrome (or a Chromium build shipping
/// the same API) with Gemini Nano downloaded and ready to run right now.
/// [isWeb] lets a test fix the platform branch instead of reading [kIsWeb].
/// [checkAvailability] lets a test fake the browser call instead of hitting
/// a real `LanguageModel` global.
Future<bool> isChromePromptApiAvailable({
  bool? isWeb,
  Future<PromptApiAvailability> Function()? checkAvailability,
}) async {
  // dart:js_interop globals don't exist on non-web platforms, so that branch
  // is checked first, mirroring receipt_recognizer_selection.dart's kIsWeb
  // pattern for the OCR engine itself.
  if (!(isWeb ?? kIsWeb)) return false;

  final availability = await (checkAvailability ?? _checkLanguageModel)();
  // Downloadable/downloading means Nano isn't ready to run yet - treated the
  // same as unavailable, since triggering and awaiting that download isn't
  // built (same call Android's field_extractor_selection.dart makes).
  return availability == PromptApiAvailability.available;
}

Future<PromptApiAvailability> _checkLanguageModel() async {
  if (!hasLanguageModelGlobal()) return PromptApiAvailability.unavailable;

  final result = await JSLanguageModel.availability().toDart;
  return PromptApiAvailability.values.byName(result.toDart);
}
