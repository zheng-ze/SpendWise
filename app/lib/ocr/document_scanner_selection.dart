import 'package:flutter/foundation.dart';

import 'document_scanner_channel.dart';

const _documentScannerChannelName = 'spendwise/document_scanner';

/// Picks the native document scanner for the current platform, or null if none is eligible right
/// now, per [isAndroidScannerEligible]'s Play Services check on Android.
Future<DocumentScannerChannel?> selectDocumentScanner({
  bool? isWeb,
  bool? isIOS,
  bool? isAndroid,
  Future<bool> Function()? isAndroidScannerEligible,
}) async {
  if (isWeb ?? kIsWeb) return null;
  final ios = isIOS ?? defaultTargetPlatform == TargetPlatform.iOS;
  if (ios) return DocumentScannerChannel(_documentScannerChannelName);

  final android = isAndroid ?? defaultTargetPlatform == TargetPlatform.android;
  if (!android) return null;

  final eligible =
      await (isAndroidScannerEligible ?? _isAndroidScannerAvailable)();
  return eligible ? DocumentScannerChannel(_documentScannerChannelName) : null;
}

Future<bool> _isAndroidScannerAvailable() {
  return DocumentScannerChannel(_documentScannerChannelName).isAvailable();
}
