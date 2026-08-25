// Raw `dart:js_interop` bindings for Chrome's built-in Prompt API
// (`LanguageModel`, Chrome 148+, https://developer.chrome.com/docs/ai/prompt-api).
// No receipt-domain logic here. That lives in
// `chrome_prompt_api_field_extractor.dart`.

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// The `LanguageModel` global the Prompt API exposes on `self`/`window`.
/// Declared as a top-level `@JS()` class, per `package:web`'s own pattern for
/// binding a global outside `window`/`navigator`.
@JS('LanguageModel')
extension type JSLanguageModel._(JSObject _) implements JSObject {
  external static JSPromise<JSString> availability();

  external static JSPromise<JSLanguageModelSession> create();
}

/// A created Prompt API session. `prompt` answers one text input with one
/// text response. `destroy` releases the session's resources.
extension type JSLanguageModelSession._(JSObject _) implements JSObject {
  external JSPromise<JSString> prompt(JSString input);

  external void destroy();
}

/// True when this JS environment declares the `LanguageModel` global at
/// all. Still says nothing about whether the model is downloaded and ready
/// to use - callers check [JSLanguageModel.availability] for that.
bool hasLanguageModelGlobal() => globalContext.has('LanguageModel');
