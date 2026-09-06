// `dart:io` fails web compilation, so this resolves to a stub returning false
// on web (the caller's own web branch never reaches this check anyway) and the
// real `Platform.isIOS` check only on native.
library;

export 'ios_platform_check_native.dart'
    if (dart.library.js_interop) 'ios_platform_check_web.dart';
