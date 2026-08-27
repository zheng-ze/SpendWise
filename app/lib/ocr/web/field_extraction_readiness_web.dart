import 'chrome_prompt_api_availability.dart';

// This file is only ever compiled into a web build, so it's safe for it to
// import code that needs dart:js_interop, which no other platform has.

Future<bool> isFieldExtractionReady() => isChromePromptApiAvailable();
