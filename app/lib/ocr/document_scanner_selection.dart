import 'package:flutter/foundation.dart';

import 'document_scanner_channel.dart';

const _documentScannerChannelName = 'spendwise/document_scanner';

/// Picks the native document scanner for the current platform, or null on a
/// platform with no camera capture (web) or no scanner wired up yet.
DocumentScannerChannel? selectDocumentScanner({
  bool? isWeb,
  bool? isIOS,
  bool? isAndroid,
}) {
  if (isWeb ?? kIsWeb) return null;
  final ios = isIOS ?? defaultTargetPlatform == TargetPlatform.iOS;
  final android = isAndroid ?? defaultTargetPlatform == TargetPlatform.android;
  if (ios || android) return DocumentScannerChannel(_documentScannerChannelName);
  return null;
}
